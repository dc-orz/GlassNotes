import CoreText
import Foundation

public enum MarkerFont {
    // Reading the name registers the font for this process. No system font installation.
    public static let name: String = {
        let packaged = Bundle.main.url(forResource: "GlassNotes_NoteDesign", withExtension: "bundle")
            .flatMap(Bundle.init(url:))
        let resources = packaged ?? Bundle.module
        guard let font = resources.url(forResource: "LXGWMarkerGothic-Regular", withExtension: "ttf"),
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(font as CFURL) as? [CTFontDescriptor],
            let descriptor = descriptors.first
        else { return "PingFangSC-Regular" }
        CTFontManagerRegisterFontsForURL(font as CFURL, .process, nil)
        return CTFontCopyPostScriptName(CTFontCreateWithFontDescriptor(descriptor, 19, nil)) as String
    }()
}
