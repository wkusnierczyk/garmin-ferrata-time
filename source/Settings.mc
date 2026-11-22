using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.WatchUi;

import Toybox.Lang;

// The app's settings: the phone's (resources/settings/settings.xml) and the watch's (SettingsMenu) read
// and write the same properties.
module Settings {

    // The demo climb instead of the watch's sensors; on until a real route ships (the plan, task 5).
    function demo() as Boolean {
        try {
            var v = Properties.getValue("demo");
            return v instanceof Boolean ? v : true;
        } catch (e) {
            return true;
        }
    }

    function setDemo(on as Boolean) as Void {
        Properties.setValue("demo", on);
    }

    // The input the setting chooses, for route r.
    function input(r as Route) as Input {
        return demo() ? new DemoInput(r) as Input : new SensorInput() as Input;
    }
}

// The settings on the watch, reached from the Ask list: one item per setting, as on the phone.
class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => "Settings"});
        addItem(new WatchUi.ToggleMenuItem("Demo", {:enabled => "demo climb", :disabled => "sensors"},
            :demo, Settings.demo(), null));
    }
}

// Selecting an item toggles it and applies it at once: the climb starts again on the new input.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :demo) {
            Settings.setDemo((item as WatchUi.ToggleMenuItem).isEnabled());
            (Application.getApp() as App).onSettingsChanged();
        }
    }
}
