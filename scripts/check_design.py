"""Reject visual literals in feature views. Native semantic styles are allowed."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
RULES = {
    "自定义颜色请放到 NoteDesign": r'\b(?:NSColor|Color)\s*\(\s*(?:red|white|hue|displayP3|sRGB)',
    "业务视图请引用语义色": r'\.(?:foregroundStyle|foregroundColor|background|tint)\(\.(?:white|black|red|orange|yellow|green|blue|purple|gray|pink|cyan|mint|indigo|teal|brown)\b',
    "业务字体请引用 Tokens.TypeStyle": r'\.font\(\s*\.(?:system|custom|title|headline|body|caption)',
    "视觉尺寸请引用 Tokens": r'\.(?:padding|cornerRadius|lineSpacing)\(\s*(?:\.\w+\s*,\s*)?\d|\b(?:cornerRadius|spacing|minHeight|maxHeight|minWidth|maxWidth|height|width):\s*\d',
    "材质与阴影由 NoteDesign 统一": r'\.(?:glassEffect|shadow)\(',
    "动画时长请引用 Tokens.Motion": r'\bduration:\s*\d',
}
def main():
    errors = []
    for path in sorted((ROOT / "Sources/GlassNotes").rglob("*.swift")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for reason, pattern in RULES.items():
                if re.search(pattern, line):
                    errors.append(f"{path.relative_to(ROOT)}:{number} {reason}")
    for msg in errors:
        print(msg)
    if errors:
        sys.exit(1)
    print("Design system checks passed.")

if __name__ == "__main__":
    main()
