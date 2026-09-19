using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

// Entry point, and the owner of state shared between the client and the view.
// Reaching it via Application.getApp() is the conventional Monkey C substitute
// for globals.
class MarleyApp extends Application.AppBase {

    // Typed so the view's data["reaction"] reads verify as container access.
    var eventData as Lang.Dictionary?;
    var statusLine as Lang.String;
    var client as MarleyClient;

    function initialize() {
        AppBase.initialize();
        eventData = null;
        statusLine = "Press START";
        client = new MarleyClient();
    }

    function onStart(state) {
        // Show the last published event immediately, before the user asks for
        // a new one -- the watch is useful even with no token configured.
        client.fetchLatest();
    }

    function onStop(state) {
        client.stopPolling();
    }

    // A watch app returns its view and the delegate that handles its buttons.
    function getInitialView() {
        return [ new MarleyView(), new MarleyDelegate() ];
    }
}
