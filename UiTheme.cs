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

    private static Color FromHex(string hex)
    {
        return ColorTranslator.FromHtml(hex);
    }

    // ---- Typography (system fonts only) --------------------------------
    public static readonly Font FontTitle = new("Segoe UI", 20f, FontStyle.Bold);
    public static readonly Font FontHeading = new("Segoe UI", 15f, FontStyle.Bold);
    public static readonly Font FontSection = new("Segoe UI", 10.5f, FontStyle.Bold);
    public static readonly Font FontBody = new("Segoe UI", 10f, FontStyle.Regular);
    public static readonly Font FontBodyBold = new("Segoe UI", 10f, FontStyle.Bold);
    public static readonly Font FontSmall = new("Segoe UI", 8.5f, FontStyle.Regular);
    public static readonly Font FontNav = new("Segoe UI", 10f, FontStyle.Bold);

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

    /// <summary>Raised surface card with a themed border and a top-down body flow.</summary>
    public sealed class GameCard : BorderedPanel
    {
        /// <summary>Top-down flow that holds the card content.</summary>
        public FlowLayoutPanel Body { get; }

        public GameCard(int height)
        {
            Height = height;
            Margin = new Padding(0, 0, 0, 10);
            Padding = new Padding(14);
            Body = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                BackColor = SurfaceRaised
            };
            Controls.Add(Body);
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
            Margin = new Padding(0, 8, 0, 6)
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

    public static void ApplyNavigationButtonStyle(Button button)
    {
        StyleButton(button, Background, TextSecondary, Background);
        button.Font = FontNav;
        button.Height = 52;
        button.Margin = new Padding(0);
        button.Dock = DockStyle.Fill;
    }

    private static void StyleButton(Button button, Color back, Color fore, Color border)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 1;
        button.FlatAppearance.BorderColor = border;
        button.BackColor = back;
        button.ForeColor = fore;
        button.Font = FontBodyBold;
        button.Height = 34;
        button.Cursor = Cursors.Hand;
        button.FlatAppearance.MouseOverBackColor = Blend(back, fore, 0.18);
        button.FlatAppearance.MouseDownBackColor = Blend(back, fore, 0.32);
    }

    private static Color Blend(Color a, Color b, double t)
    {
        return Color.FromArgb(
            (int)(a.R + (b.R - a.R) * t),
            (int)(a.G + (b.G - a.G) * t),
            (int)(a.B + (b.B - a.B) * t));
    }

    /// <summary>Marks a navigation button as the selected tab.</summary>
    public static void SetNavigationSelected(Button button, bool selected)
    {
        button.BackColor = selected ? SurfaceRaised : Background;
        button.ForeColor = selected ? Accent : TextSecondary;
    }
}
