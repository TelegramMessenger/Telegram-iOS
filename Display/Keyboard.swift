import Foundation

#if BUCK
import DisplayPrivate
#endif

public enum Keyboard {
    public static func applyAutocorrection() {
        applyKeyboardAutocorrection()
    }
}
