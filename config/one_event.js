// MARLEY job configuration: exactly ONE nu_e + 40Ar charged-current event.
//
// Derived from examples/config/COPY_ME.js in the MARLEY v2.0.0 source, with
// two deliberate changes:
//   * "ES.react" (elastic scattering off atomic electrons) is omitted, so the
//     single event is always a CC interaction on the nucleus rather than
//     occasionally a much less interesting electron recoil.
//   * events is 1, and the seed is substituted at run time by
//     scripts/run_marley.sh so each invocation produces a different event
//     while still recording the seed needed to reproduce it.
{
  seed: __SEED__,

  // Pure 40Ar target (PDG nuclear code 10LZZZAAAI -> 1000180400 = Z 18, A 40)
  target: {
    nuclides: [ 1000180400 ],
    atom_fractions: [ 1.0 ],
  },

  // Recommended MARLEY v2 cross-section models: HF-CRPA for the continuum and
  // Bhattacharya2009 for discrete nuclear transitions.
  reactions: [
    "ve40ArCC_HF-CRPA.react",
    "ve40ArCC_Bhattacharya2009-Discrete.react",
  ],

  // Pinched Fermi-Dirac spectrum, the usual stand-in for supernova nu_e.
  source: {
    type: "fermi-dirac",
    neutrino: "ve",
    Emin: 0,             // MeV
    Emax: 60,            // MeV
    temperature: 3.5,    // MeV
    eta: 4               // pinching parameter (dimensionless)
  },

  direction: { x: 0.0, y: 0.0, z: 1.0 },

  // Settings for the "marley generate" command (a v2 layout change: in v1 the
  // events and output keys sat at the top level).
  generate: {
    events: 1,
    // "force": true is required as well as mode "overwrite" -- without it
    // MARLEY stops and prompts "Overwrite file events.hepmc3 [y/n]?", which
    // has nothing to answer it in CI.
    output: [ { file: "events.hepmc3", format: "ascii", mode: "overwrite",
                force: true } ],
  },
}
