"""Source-level guards for popup color roles; no running shell required."""

from pathlib import Path
import re
import unittest


class PanelColorTests(unittest.TestCase):
    def test_popup_uses_popup_text_role(self):
        source = Path(__file__).with_name("StatusPanel.qml").read_text()
        self.assertRegex(
            source,
            r"readonly property color panelForeground:\s*Commons\.Color\.popups\.text",
        )
        self.assertNotIn("barForeground", source)
        # Cover text, separators, and both switches, including future additions.
        bindings = re.findall(r"\b(?:color|foreground):\s*([^;\n}]+)", source)
        self.assertTrue(bindings)
        self.assertTrue(all(value.strip() == "root.panelForeground" for value in bindings))

    def test_bar_keeps_adaptive_foreground(self):
        source = Path(__file__).with_name("Widget.qml").read_text()
        self.assertIn("color: button.foreground", source)
        self.assertNotIn("Color.popups.text", source)


if __name__ == "__main__":
    unittest.main()
