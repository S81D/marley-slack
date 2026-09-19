using Toybox.Application;
using Toybox.WatchUi;

// BehaviorDelegate maps physical buttons to semantic actions, so this works
// on both button watches (fenix) and touchscreens without change.
class MarleyDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // START/ENTER: generate a new event.
    function onSelect() {
        Application.getApp().client.summon();
        return true;
    }

    // DOWN: re-read what is published without triggering a build.
    function onNextPage() {
        Application.getApp().client.fetchLatest();
        return true;
    }
}
