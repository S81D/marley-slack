#!/usr/bin/env python3
"""Extract a short, Slack-ready summary from a MARLEY HepMC3 ASCII event file.

This deliberately is *not* a general HepMC3 parser (see SPEC.md section 14) -- it
pulls out only the handful of quantities the Slack message quotes, and omits any
field it cannot find rather than guessing.

Relevant line formats, per MARLEY's docs/interpret_output.rst:

    E <event_number> <n_vertices> <n_particles>
    U <energy_unit> <length_unit>            always "MEV CM" as written by MARLEY
    A <id> <key> <value>...                  attributes; id 0 = the whole event
    A <key> <value>...                       run-info attributes (no id)
    V <id> <status> [<incoming ids>] [@ x y z t]
    P <id> <parent_vertex> <pdg> <px> <py> <pz> <E> <mass> <status>

Particle status codes used below: 4 = incident projectile, 20 = struck target,
1 = final-state, 27/28 = intermediate nuclei between de-excitation steps.
All energies are MeV.
"""

import argparse
import sys

# Z -> symbol. 40Ar de-excitation can emit n/p/alpha, so the residue may sit a
# few Z below argon; this range covers everything reachable from a 40Ar target.
ELEMENTS = {
    1: "H", 2: "He", 3: "Li", 4: "Be", 5: "B", 6: "C", 7: "N", 8: "O",
    9: "F", 10: "Ne", 11: "Na", 12: "Mg", 13: "Al", 14: "Si", 15: "P",
    16: "S", 17: "Cl", 18: "Ar", 19: "K", 20: "Ca", 21: "Sc", 22: "Ti",
}

SUPERSCRIPT = str.maketrans("0123456789", "⁰¹²³⁴⁵⁶⁷⁸⁹")

# Only the species MARLEY can put in a final state at tens of MeV.
PARTICLE_NAMES = {
    11: "e⁻", -11: "e⁺", 13: "μ⁻", -13: "μ⁺",
    12: "νe", -12: "ν̄e", 14: "νμ", -14: "ν̄μ", 16: "ντ", -16: "ν̄τ",
    22: "γ", 2112: "n", 2212: "p",
}

# Order matters: the barred neutrino (nu + U+0304) must be replaced before
# plain nu, and superscript digits before anything else.
ASCII_MAP = [
    ("\u03bd\u0304", "nubar"), ("\u03bd", "nu"), ("\u03bc", "mu"), ("\u03b3", "gamma"),
    ("\u2192", "->"), ("\u207b", "-"), ("\u207a", "+"),
    ("\u2070", "0"), ("\u00b9", "1"), ("\u00b2", "2"), ("\u00b3", "3"), ("\u2074", "4"),
    ("\u2075", "5"), ("\u2076", "6"), ("\u2077", "7"), ("\u2078", "8"), ("\u2079", "9"),
]


def to_ascii(text):
    """Flatten the display strings to characters Garmin's fonts actually have."""
    for src, dst in ASCII_MAP:
        text = text.replace(src, dst)
    return text


LEPTON_PDGS = {11, 12, 13, 14, 15, 16}
NUCLEUS_PDG_MIN = 1_000_000_000


def is_nucleus(pdg):
    """PDG nuclear codes are 10LZZZAAAI, i.e. ten digits starting with 10."""
    return abs(pdg) >= NUCLEUS_PDG_MIN


def nuclide_name(pdg):
    """Decode a PDG nuclear code into e.g. '⁴⁰Ar'. 1000180400 -> Z=18, A=40."""
    A = (pdg // 10) % 1000
    Z = (pdg // 10000) % 1000
    symbol = ELEMENTS.get(Z, f"Z={Z}")
    return f"{str(A).translate(SUPERSCRIPT)}{symbol}"


def particle_name(pdg):
    if is_nucleus(pdg):
        return nuclide_name(pdg)
    return PARTICLE_NAMES.get(pdg, f"PDG {pdg}")


def parse_first_event(path):
    """Read the first event in a HepMC3 ASCII file.

    Returns (event_number, energy_unit, attributes, particles, vertices).
    Unknown line types are ignored, so run-info blocks and any future HepMC3
    additions pass through harmlessly.
    """
    event_number = None
    energy_unit = None
    attributes = {}          # (target_id, key) -> raw string value
    particles = []
    vertices = {}            # vertex id -> list of incoming particle ids

    with open(path) as handle:
        for line in handle:
            fields = line.split()
            if not fields:
                continue
            tag = fields[0]

            if tag == "E":
                # A second E line means a second event; we only summarize one.
                if event_number is not None:
                    break
                event_number = int(fields[1])

            elif tag == "U" and len(fields) >= 2:
                energy_unit = fields[1]

            elif tag == "A" and len(fields) >= 3:
                # Event attributes are "A <id> <key> <value>", but the run-info
                # block at the top of a real file uses "A <key> <value>" with no
                # id at all (the example in MARLEY's docs omits that block).
                # Those are stored under a None id.
                try:
                    attributes[(int(fields[1]), fields[2])] = " ".join(fields[3:])
                except ValueError:
                    attributes[(None, fields[1])] = " ".join(fields[2:])

            elif tag == "V" and len(fields) >= 4:
                incoming = fields[3].strip("[]")
                vertices[int(fields[1])] = (
                    [int(x) for x in incoming.split(",") if x] if incoming else []
                )

            elif tag == "P" and len(fields) >= 10:
                particles.append({
                    "id": int(fields[1]),
                    "parent": int(fields[2]),
                    "pdg": int(fields[3]),
                    "energy": float(fields[7]),
                    "mass": float(fields[8]),
                    "status": int(fields[9]),
                })

    return event_number, energy_unit, attributes, particles, vertices


def find_primary_vertex(projectile, particles, vertices):
    """Identify the vertex of the primary interaction.

    Located by finding the vertex that the incident neutrino feeds into, rather
    than assuming it is vertex -1 -- HepMC3 numbering order is not guaranteed.
    """
    if projectile is not None:
        for vertex_id, incoming in vertices.items():
            if projectile["id"] in incoming:
                return vertex_id
    # Fall back to the first-created vertex (ids are negative, so max()).
    parents = {p["parent"] for p in particles if p["parent"] < 0}
    return max(parents) if parents else None


def summarize(path):
    """Build an ordered dict of flat string fields describing the event."""
    event_number, energy_unit, attributes, particles, vertices = parse_first_event(path)

    fields = {}
    if not particles:
        return {"parse_ok": "false"}

    if energy_unit and energy_unit.upper() != "MEV":
        # Guard against silently reporting GeV numbers labelled as MeV.
        print(f"warning: energy unit is {energy_unit}, not MEV; "
              "values below are as written in the file", file=sys.stderr)
    unit = {"MEV": "MeV", "GEV": "GeV", "KEV": "keV"}.get(
        (energy_unit or "MEV").upper(), energy_unit or "MeV")

    projectile = next((p for p in particles if p["status"] == 4), None)
    target = next((p for p in particles if p["status"] == 20), None)
    final_state = [p for p in particles if p["status"] == 1]

    # Outgoing particles of the primary vertex: the ejectile lepton and the
    # (generally excited) residual nucleus, before any de-excitation.
    primary_vertex = find_primary_vertex(projectile, particles, vertices)
    primary = [p for p in particles if p["parent"] == primary_vertex]
    ejectile = next((p for p in primary if abs(p["pdg"]) in LEPTON_PDGS), None)
    primary_residue = next((p for p in primary if is_nucleus(p["pdg"])), None)

    if event_number is not None:
        fields["event_number"] = str(event_number)

    if projectile is not None:
        fields["energy"] = f"{projectile['energy']:.1f} {unit}"
        fields["energy_value"] = f"{projectile['energy']:.1f}"
        fields["energy_unit"] = unit

    # "νe + ⁴⁰Ar → e⁻ + ⁴⁰K*", with the star only if the residue is excited.
    if None not in (projectile, target, ejectile, primary_residue):
        excitation = attributes.get((primary_residue["id"], "Ex"))
        star = "*" if excitation and float(excitation) > 0.0 else ""
        fields["reaction"] = (
            f"{particle_name(projectile['pdg'])} + {particle_name(target['pdg'])}"
            f" → {particle_name(ejectile['pdg'])}"
            f" + {particle_name(primary_residue['pdg'])}{star}"
        )
        if excitation:
            fields["residue_ex"] = f"{float(excitation):.3f} {unit}"

    if ejectile is not None:
        fields["lepton"] = particle_name(ejectile["pdg"])
        fields["lepton_ke"] = f"{ejectile['energy'] - ejectile['mass']:.1f} {unit}"

    # The nucleus left once the de-excitation cascade has finished. Pick the
    # HEAVIEST final nucleus: ~1% of events eject an alpha, and taking the
    # first nucleus would report the alpha as the residue.
    nuclei = [p for p in final_state if is_nucleus(p["pdg"])]
    if nuclei:
        heaviest = max(nuclei, key=lambda p: (p["pdg"] // 10) % 1000)
        fields["residue"] = particle_name(heaviest["pdg"])
        nuclei.remove(heaviest)

    # Everything else the de-excitation threw off: nucleons plus any light
    # nuclei (alphas) that are not the residue.
    ejected = [p for p in final_state if p["pdg"] in (2112, 2212)] + nuclei
    if ejected:
        tally = {}
        for particle in ejected:
            label = particle_name(particle["pdg"])
            tally[label] = tally.get(label, 0) + 1
        # "1n"/"2p" read fine, but a nuclide label already starts with its
        # mass number, so "1" + "4He" would read as fourteen. Space those.
        fields["ejected"] = " ".join(
            (f"{n} {label}" if label[0].isdigit() else f"{n}{label}")
            for label, n in sorted(tally.items()))
    else:
        fields["ejected"] = "none"

    gammas = [p for p in final_state if p["pdg"] == 22]
    fields["gammas"] = str(len(gammas))
    if gammas:
        # Sum should recover the primary residue's excitation energy whenever
        # nothing else was ejected -- a useful consistency check.
        fields["gamma_sum"] = f"{sum(g['energy'] for g in gammas):.3f} {unit}"
        brightest = sorted((g["energy"] for g in gammas), reverse=True)[:3]
        fields["gamma_top"] = " / ".join(f"{e:.2f}" for e in brightest)

    # Real output declares its own cross-section unit in the run-info block
    # (NuHepMC.Units.CrossSection.*), so label it from the file rather than
    # assuming. Files without that block report the bare number instead.
    total_xsec = attributes.get((0, "tot_xs"))
    if total_xsec:
        xsec_unit = attributes.get((None, "NuHepMC.Units.CrossSection.Unit"))
        target_scale = attributes.get((None, "NuHepMC.Units.CrossSection.TargetScale"))
        if xsec_unit:
            scale = f" ({target_scale})" if target_scale else ""
            fields["xsec"] = f"{float(total_xsec):.4g} {xsec_unit}{scale}"
        else:
            fields["xsec_raw"] = total_xsec

    # MARLEY records the seed it used, which is what makes an event reproducible.
    seed = attributes.get((None, "MARLEY.RNGseed"))
    if seed:
        fields["seed"] = seed

    fields["parse_ok"] = "true" if "reaction" in fields else "false"
    return fields


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("event_file", help="MARLEY HepMC3 ASCII output file")
    parser.add_argument("--text", action="store_true",
                        help="print a human-readable block instead of key=value")
    parser.add_argument("--ascii", action="store_true",
                        help="transliterate to ASCII (Garmin fonts lack the symbols)")
    args = parser.parse_args()

    fields = summarize(args.event_file)
    if args.ascii:
        fields = {k: to_ascii(v) for k, v in fields.items()}

    if args.text:
        width = max(len(k) for k in fields)
        print("MARLEY event summary")
        for key, value in fields.items():
            print(f"  {key:<{width}} : {value}")
    else:
        # key=value lines, ready to append to $GITHUB_OUTPUT.
        for key, value in fields.items():
            print(f"{key}={value}")


if __name__ == "__main__":
    main()
