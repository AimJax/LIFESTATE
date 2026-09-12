using System;
using System.ComponentModel;
using System.Drawing;
using System.Windows.Forms;

namespace Lifestate;

/// <summary>
/// Centralized visual theme for the LIFESTATE game UI.
/// Presentation-only: no gameplay state, no persistence.
/// Dark navy/charcoal foundation with a restrained cool blue accent.
/// </summary>
public static class UiTheme
{
    // ---- Palette -------------------------------------------------------
    public static readonly Color Background = FromHex("#0D1117");
    public static readonly Color Surface = FromHex("#151B23");
    public static readonly Color SurfaceRaised = FromHex("#1C2430");
    public static readonly Color Border = FromHex("#2A3441");

    public static readonly Color TextPrimary = FromHex("#E6EDF3");
    public static readonly Color TextSecondary = FromHex("#8B98A7");
    public static readonly Color TextMuted = FromHex("#596675");

    public static readonly Color Accent = FromHex("#5FA8FF");
    public static readonly Color Positive = FromHex("#63D297");
    public static readonly Color Warning = FromHex("#E5B567");
    public static readonly Color Negative = FromHex("#E06C75");

    /// <summary>Muted blue for secondary progress emphasis (e.g. Thirst).</summary>
    public static readonly Color AccentMuted = FromHex("#4A7CB0");

    private static Color FromHex(string hex)
    {
        return ColorTranslator.FromHtml(hex);
    }

    // ---- Spacing system --------------------------------------------------
    public const int SpaceXs = 4;
    public const int SpaceSm = 8;
    public const int SpaceMd = 16;
    public const int SpaceLg = 24;
    public const int SpaceXl = 32;

    // ---- Size system -----------------------------------------------------
    public const int ContentMaxWidth = 1180;
    /// <summary>Life is a single vertical feed, so it uses a narrower reading column.</summary>
    public const int LifeContentMaxWidth = 1000;
    public const int TopBarHeight = 56;
    public const int NavHeight = 64;
    public const int CardPadding = 18;
    public const int ButtonHeight = 40;
    public const int ButtonHeightSmall = 30;

    // ---- Typography (system fonts only) --------------------------------
    public static readonly Font FontTitle = new("Segoe UI", 20f, FontStyle.Bold);
    public static readonly Font FontScreenTitle = new("Segoe UI", 16f, FontStyle.Bold);
    public static readonly Font FontDisplay = new("Segoe UI", 24f, FontStyle.Bold);
    /// <summary>Life identity age: the strongest value on the screen, but kept inside the heading range.</summary>
    public static readonly Font FontLifeAge = new("Segoe UI", 20f, FontStyle.Bold);
    public static readonly Font FontHeading = new("Segoe UI", 15f, FontStyle.Bold);
    public static readonly Font FontValue = new("Segoe UI", 12.5f, FontStyle.Bold);
    public static readonly Font FontSection = new("Segoe UI", 10.5f, FontStyle.Bold);
    public static readonly Font FontBody = new("Segoe UI", 10f, FontStyle.Regular);
    public static readonly Font FontBodyBold = new("Segoe UI", 10f, FontStyle.Bold);
    public static readonly Font FontSmall = new("Segoe UI", 8.5f, FontStyle.Regular);
    public static readonly Font FontTag = new("Segoe UI", 8.5f, FontStyle.Bold);
    public static readonly Font FontNav = new("Segoe UI", 10.5f, FontStyle.Bold);

    // ---- Surfaces ------------------------------------------------------
    /// <summary>Opaque panel with the base background color.</summary>
    public static Panel CreatePanel(Color backColor, int padAll = 0)
    {
        var panel = new Panel
        {
            BackColor = backColor,
            Padding = new Padding(padAll),
            Dock = DockStyle.Fill
        };
        return panel;
    }

    /// <summary>Panel with a 1px theme border drawn on top. Border color is settable for highlights.</summary>
    public class BorderedPanel : Panel
    {
        [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
        public Color BorderColor { get; set; } = Border;

        public BorderedPanel()
        {
            BackColor = SurfaceRaised;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            using var pen = new Pen(BorderColor);
            e.Graphics.DrawRectangle(pen, 0, 0, Width - 1, Height - 1);
        }
    }

    /// <summary>Creates a bold section header label in secondary text color.</summary>
    public static Label CreateSectionHeader(string text)
    {
        return new Label
        {
            Text = text,
            Font = FontSection,
            ForeColor = TextSecondary,
            AutoSize = true,
            Margin = new Padding(0, SpaceSm, 0, 6)
        };
    }

    /// <summary>Creates a value label (primary text, body font).</summary>
    public static Label CreateValueLabel(string text = "")
    {
        return new Label
        {
            Text = text,
            Font = FontBody,
            ForeColor = TextPrimary,
            AutoSize = true,
            Margin = new Padding(0, 1, 0, 1)
        };
    }

    /// <summary>Creates a muted secondary-text label.</summary>
    public static Label CreateMutedLabel(string text = "")
    {
        return new Label
        {
            Text = text,
            Font = FontSmall,
            ForeColor = TextSecondary,
            AutoSize = true,
            Margin = new Padding(0, 1, 0, 1)
        };
    }

    /// <summary>Creates a small uppercase tag label (section labels, status tags).</summary>
    public static Label CreateTag(string text, Color? color = null)
    {
        return new Label
        {
            Text = text,
            Font = FontTag,
            ForeColor = color ?? TextMuted,
            AutoSize = true,
            Margin = new Padding(0, 0, 0, SpaceXs)
        };
    }

    // ---- Buttons -------------------------------------------------------
    public static void ApplyPrimaryButtonStyle(Button button)
    {
        StyleButton(button, SurfaceRaised, Accent, Border);
    }

    public static void ApplySecondaryButtonStyle(Button button)
    {
        StyleButton(button, SurfaceRaised, TextPrimary, Border);
    }

    public static void ApplyDangerButtonStyle(Button button)
    {
        StyleButton(button, SurfaceRaised, Negative, Border);
    }

    /// <summary>Compact status pill for the top bar (Running / Paused).</summary>
    public static void ApplyStatusPillStyle(Button button)
    {
        StyleButton(button, Surface, TextSecondary, Border);
        button.AutoSize = false;
        button.Height = 28;
        button.Padding = new Padding(10, 0, 10, 0);
        button.Font = FontTag;
        button.Margin = new Padding(0, 14, 0, 0);
    }

    /// <summary>Compact utility button for secondary action strips.</summary>
    public static void ApplyUtilityButtonStyle(Button button)
    {
        StyleButton(button, SurfaceRaised, TextSecondary, Border);
        button.Height = ButtonHeightSmall;
        button.Padding = new Padding(8, 0, 8, 0);
        button.Font = FontSmall;
    }

    private static void StyleButton(Button button, Color back, Color fore, Color border)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 1;
        button.FlatAppearance.BorderColor = border;
        button.BackColor = back;
        button.ForeColor = fore;
        button.Font = FontBodyBold;
        button.Height = ButtonHeight;
        button.Padding = new Padding(14, 0, 14, 0);
        button.Cursor = Cursors.Hand;
        button.FlatAppearance.MouseOverBackColor = Blend(back, fore, 0.16);
        button.FlatAppearance.MouseDownBackColor = Blend(back, fore, 0.30);
    }

    private static Color Blend(Color a, Color b, double t)
    {
        return Color.FromArgb(
            (int)(a.R + (b.R - a.R) * t),
            (int)(a.G + (b.G - a.G) * t),
            (int)(a.B + (b.B - a.B) * t));
    }

    /// <summary>
    /// Custom-painted bottom navigation tab: accent top indicator line, raised
    /// surface and accent text when selected; subdued otherwise.
    /// </summary>
    public sealed class GameNavButton : Control
    {
        private bool _selected;
        private bool _hover;

        [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
        public bool Selected
        {
            get => _selected;
            set
            {
                if (_selected == value) return;
                _selected = value;
                Invalidate();
            }
        }

        public GameNavButton()
        {
            SetStyle(
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.UserPaint |
                ControlStyles.ResizeRedraw,
                true);
            BackColor = Background;
            Font = FontNav;
            Cursor = Cursors.Hand;
            TabStop = false;
        }

        protected override void OnMouseEnter(EventArgs e)
        {
            base.OnMouseEnter(e);
            _hover = true;
            Invalidate();
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            _hover = false;
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            var g = e.Graphics;
            var rect = ClientRectangle;

            Color back = _selected
                ? SurfaceRaised
                : _hover ? Blend(Background, TextSecondary, 0.06) : Background;
            using (var b = new SolidBrush(back))
            {
                g.FillRectangle(b, rect);
            }

            if (_selected)
            {
                using var accentBar = new SolidBrush(Accent);
                g.FillRectangle(accentBar, 0, 0, rect.Width, 3);
            }

            Color fore = _selected ? Accent : _hover ? TextPrimary : TextSecondary;
            TextRenderer.DrawText(
                g, Text, Font, rect, fore,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }
    }
}
