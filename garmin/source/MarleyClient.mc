using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.Timer;
using Toybox.WatchUi;

// Talks to GitHub: dispatches the workflow, then polls for the result.
class MarleyClient {

    // Pages, not raw.githubusercontent.com: raw serves .json as text/plain,
    // which HTTP_RESPONSE_CONTENT_TYPE_JSON refuses to parse.
    const DISPATCH_URL = "https://api.github.com/repos/S81D/marley-slack/actions/workflows/marley-generate.yml/dispatches";
    const EVENT_URL = "https://s81d.github.io/marley-slack/latest_event.json";

    const POLL_MS = 20000;  // MARLEY takes ~2 min in CI, so poll every 20 s
    const POLL_MAX = 9;     // ...and give up after ~3 minutes

    var timer as Timer.Timer?;
    var polls as Lang.Number;
    var baseline as Lang.String?;  // generated_at before we asked; a change means a NEW event

    function initialize() {
        timer = null;
        polls = 0;
        baseline = null;
    }

    // START button: ask GitHub Actions to generate an event.
    function summon() as Void {
        var app = Application.getApp();
        var token = getToken();

        baseline = stampOf(app.eventData);

        if (token == null) {
            // No token: degrade to viewer mode rather than failing. This is
            // also how the app behaves in the simulator before you set one.
            app.statusLine = "No token - refreshing";
            WatchUi.requestUpdate();
            fetchLatest();
            return;
        }

        app.statusLine = "Summoning...";
        WatchUi.requestUpdate();

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Accept" => "application/vnd.github+json",
                // GitHub rejects requests with no User-Agent (403), which would
                // otherwise be indistinguishable from a bad token.
                "User-Agent" => "marley-slack-garmin",
                "Authorization" => "Bearer " + token
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(DISPATCH_URL, { "ref" => "main" },
                                      options, method(:onDispatch));
    }

    // A successful dispatch answers 204 No Content, so `data` arriving null
    // here is success, not an error. Anything 2xx counts.
    function onDispatch(responseCode as Lang.Number,
                          data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        var app = Application.getApp();
        if (responseCode >= 200 && responseCode < 300) {
            app.statusLine = "Building...";
            startPolling();
        } else if (responseCode == 401 || responseCode == 403) {
            app.statusLine = "Token rejected (" + responseCode + ")";
        } else {
            app.statusLine = "Dispatch failed (" + responseCode + ")";
        }
        WatchUi.requestUpdate();
    }

    // Read whatever is currently published. Safe to call any time.
    function fetchLatest() as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(EVENT_URL, null, options, method(:onEvent));
    }

    function onEvent(responseCode as Lang.Number,
                          data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        var app = Application.getApp();

        if (responseCode == 200 && data != null) {
            var fresh = !sameStamp(stampOf(data), baseline);
            app.eventData = data as Lang.Dictionary;
            if (timer == null) {
                app.statusLine = "";
            } else if (fresh) {
                stopPolling();      // the event we asked for has landed
                app.statusLine = "";
            }
        } else if (responseCode == 404) {
            app.statusLine = "Nothing published yet";
        } else {
            app.statusLine = "Fetch failed (" + responseCode + ")";
        }
        WatchUi.requestUpdate();
    }

    // Each poll is a tiny callback, so the watchdog never sees a long-running
    // loop -- the waiting happens in the timer, not in our code.
    function startPolling() as Void {
        polls = 0;
        if (timer == null) {
            timer = new Timer.Timer();
        }
        timer.start(method(:onPoll), POLL_MS, true);
    }

    function onPoll() as Void {
        polls = polls + 1;
        if (polls > POLL_MAX) {
            Application.getApp().statusLine = "Timed out - press START";
            stopPolling();
            WatchUi.requestUpdate();
            return;
        }
        fetchLatest();
    }

    function stopPolling() as Void {
        if (timer != null) {
            timer.stop();
            timer = null;
        }
        polls = 0;
    }

    function getToken() as Lang.String? {
        var token = null;
        try {
            token = Application.Properties.getValue("githubToken");
        } catch (ex) {
            token = null;
        }
        if (token != null && token.length() == 0) {
            token = null;
        }
        return token;
    }

    function stampOf(data as Lang.Dictionary?) as Lang.String? {
        if (data == null) { return null; }
        return data["generated_at"] as Lang.String?;
    }

    function sameStamp(a as Lang.String?, b as Lang.String?) as Lang.Boolean {
        if (a == null || b == null) { return false; }
        return a.equals(b);
    }
}
