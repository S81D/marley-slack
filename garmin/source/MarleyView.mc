using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

// Draws the event. Every value arrives from latest_event.json already
// formatted as a display string, so there is no number formatting on-device.
class MarleyView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var data = app.eventData;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 92, Graphics.FONT_XTINY, "MARLEY",
                    Graphics.TEXT_JUSTIFY_CENTER);

        if (data == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 10, Graphics.FONT_SMALL, app.statusLine,
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // A failed run still publishes a payload, so say so rather than
        // showing a stale event as though it were fresh.
        if (!"success".equals(data["status"])) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 10, Graphics.FONT_SMALL,
                        "run " + data["status"], Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 58, Graphics.FONT_XTINY, data["reaction"],
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 32, Graphics.FONT_NUMBER_MEDIUM, data["energy"],
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 22, Graphics.FONT_XTINY,
                    data["lepton"] + "  KE " + data["lepton_ke"],
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + 42, Graphics.FONT_XTINY,
                    data["residue"] + "   " + data["gammas"] + " gamma",
                    Graphics.TEXT_JUSTIFY_CENTER);

        if (app.statusLine != null && app.statusLine.length() > 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 66, Graphics.FONT_XTINY, app.statusLine,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
