using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class AviatorlikeApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }


    
    
        //! Return the initial view for the app
    //! @return Array Pair [View, Delegate] or Array [View]
    public function getInitialView() as Array<Views or InputDelegates>? {
        if (WatchUi has :WatchFaceDelegate) {
            var view = new $.AviatorlikeView();
            var delegate = new $.AviatorlikeDelegate(view);
            return [view, delegate] as Array<Views or InputDelegates>;
        } else {
            return [new $.AviatorlikeView()] as Array<Views>;
        }
    }
    
    
    
    
    

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        Ui.requestUpdate();
    }

}