using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Draws the event. Values arrive from latest_event.json already formatted as
// ASCII display strings, so there is no formatting or transliteration on-device.
class MarleyView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = Application.getApp();
        var data = app.eventData as Lang.Dictionary?;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 95, Graphics.FONT_XTINY, "MARLEY",
                    Graphics.TEXT_JUSTIFY_CENTER);

        if (data == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 10, Graphics.FONT_SMALL, app.statusLine,
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // A failed run still publishes a payload, so report that rather than
        // showing a stale event as though it were fresh.
        if (!"success".equals(data["status"])) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 10, Graphics.FONT_SMALL,
                        "run " + data["status"], Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 68, Graphics.FONT_XTINY, data["reaction"],
                    Graphics.TEXT_JUSTIFY_CENTER);

        drawEnergy(dc, cx, cy, data);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 24, Graphics.FONT_XTINY,
                    data["lepton"] + "   KE " + data["lepton_ke"],
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + 46, Graphics.FONT_XTINY,
                    data["residue"] + "   " + data["gammas"] + " gamma",
                    Graphics.TEXT_JUSTIFY_CENTER);

        if (app.statusLine != null && app.statusLine.length() > 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 68, Graphics.FONT_XTINY, app.statusLine,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // FONT_NUMBER_* contains digits and punctuation only -- no letters -- so
    // "17.0 MeV" drawn in it renders the unit as empty boxes. Draw the number
    // in the big font and the unit beside it in a text font, centring the pair.
    hidden function drawEnergy(dc as Graphics.Dc, cx as Lang.Number,
                               cy as Lang.Number, data as Lang.Dictionary) as Void {
        var value = data["energy_value"];

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);

        if (value == null) {
            // Older payload with only the combined string: use a text font so
            // the unit still renders rather than becoming boxes.
            dc.drawText(cx, cy - 34, Graphics.FONT_MEDIUM, data["energy"],
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var numberFont = Graphics.FONT_NUMBER_MEDIUM;
        var unit = data["energy_unit"];
        var unitText = (unit == null) ? "" : unit.toString();

        var valueWidth = dc.getTextWidthInPixels(value.toString(), numberFont);
        var unitWidth = (unitText.length() == 0)
            ? 0 : dc.getTextWidthInPixels(unitText, Graphics.FONT_XTINY);
        var gap = (unitWidth > 0) ? 6 : 0;

        var left = cx - (valueWidth + gap + unitWidth) / 2;
        var top = cy - 46;
        dc.drawText(left, top, numberFont, value, Graphics.TEXT_JUSTIFY_LEFT);

        if (unitWidth > 0) {
            // Sit the unit on the number's baseline instead of its top.
            var baseline = top + dc.getFontHeight(numberFont)
                               - dc.getFontHeight(Graphics.FONT_XTINY) - 4;
            dc.drawText(left + valueWidth + gap, baseline, Graphics.FONT_XTINY,
                        unitText, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}
