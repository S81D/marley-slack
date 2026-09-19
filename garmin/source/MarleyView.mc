using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// The Feynman diagram is the backdrop and the event data is labelled onto its
// limbs. That is only honest because the topology is fixed: a 500-event scan of
// config/one_event.js produced exactly one charged lepton and one residual
// nucleus in 500/500 events. DEPICTED_REACTION re-checks it at runtime.
class MarleyView extends WatchUi.View {

    const DEPICTED_REACTION = "nue + 40Ar -> e- + 40K*";

    hidden var diagram;
    hidden var atom;

    function initialize() {
        View.initialize();
        // Loaded once: onUpdate runs often and these are the largest objects
        // the app holds.
        diagram = WatchUi.loadResource(Rez.Drawables.Diagram);
        atom = WatchUi.loadResource(Rez.Drawables.Atom);
    }

    // Dictionary access yields null for absent keys, so a payload predating a
    // field degrades to a blank line rather than crashing.
    hidden function textOf(data as Lang.Dictionary, key as Lang.String) as Lang.String {
        var value = data[key];
        return (value == null) ? "" : value.toString();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = Application.getApp();
        var data = app.eventData as Lang.Dictionary?;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        if (data == null) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 95, Graphics.FONT_XTINY, "MARLEY",
                        Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 10, Graphics.FONT_SMALL, app.statusLine,
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (!"success".equals(data["status"])) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 10, Graphics.FONT_SMALL,
                        "run " + data["status"], Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // If the generator config ever changes reaction, show text rather than
        // a diagram that would misstate the physics.
        if (!DEPICTED_REACTION.equals(data["reaction"])) {
            drawFallback(dc, cx, cy, data);
            return;
        }

        dc.drawBitmap(cx - (diagram.getWidth() / 2), 34, diagram);

        // Each label sits at the tip of the limb it belongs to. The diagram's
        // own captions were stripped from the SVG so these are the only labels,
        // and unlike the fixed captions they describe the actual event.

        // Upper-left: the excited remnant leaving the vertex.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(36, 44, Graphics.FONT_XTINY, textOf(data, "residue") + "*",
                    Graphics.TEXT_JUSTIFY_LEFT);
        var ex = textOf(data, "residue_ex");
        if (ex.length() > 0) {
            dc.drawText(20, 62, Graphics.FONT_XTINY, "Ex " + ex,
                        Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Upper-right: the outgoing electron.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(224, 44, Graphics.FONT_XTINY, "e-", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(236, 62, Graphics.FONT_XTINY, textOf(data, "lepton_ke"),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Lower-right: the incoming neutrino.
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(240, 140, Graphics.FONT_XTINY, "nue", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(246, 158, Graphics.FONT_XTINY, textOf(data, "energy"),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Lower-left: the target nucleus.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(22, 150, Graphics.FONT_XTINY, "40Ar", Graphics.TEXT_JUSTIFY_LEFT);

        drawDeexcitation(dc, data);
    }

    // Bottom strip: what the excited nucleus shed on the way down.
    hidden function drawDeexcitation(dc as Graphics.Dc,
                                     data as Lang.Dictionary) as Void {
        dc.drawBitmap(78, 166, atom);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(118, 172, Graphics.FONT_XTINY, textOf(data, "residue"),
                    Graphics.TEXT_JUSTIFY_LEFT);

        // "1 gamma" but "4 gammas".
        var count = textOf(data, "gammas");
        var sum = textOf(data, "gamma_sum");
        var line = count + ("1".equals(count) ? " gamma " : " gammas ") + sum;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(130, 204, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_CENTER);

        var ejected = textOf(data, "ejected");
        if (ejected.length() > 0 && !"none".equals(ejected)) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(130, 222, Graphics.FONT_XTINY, "ejected " + ejected,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Used only if the published reaction stops matching the diagram.
    hidden function drawFallback(dc as Graphics.Dc, cx as Lang.Number,
                                 cy as Lang.Number, data as Lang.Dictionary) as Void {
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 95, Graphics.FONT_XTINY, "MARLEY",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 60, Graphics.FONT_XTINY, textOf(data, "reaction"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 20, Graphics.FONT_MEDIUM, textOf(data, "energy"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 30, Graphics.FONT_XTINY,
                    textOf(data, "lepton") + "  KE " + textOf(data, "lepton_ke"),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
