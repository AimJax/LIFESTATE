using System;
using System.ComponentModel;
using System.Drawing;
using System.Windows.Forms;

namespace Lifestate;

/// <summary>
/// Lightweight presentation-only progress bar drawn with the game palette.
/// Holds no gameplay state and no persistence; values are set by the UI layer.
/// </summary>
public sealed class GameProgressBar : Control
{
    private double _minimum = 0d;
    private double _maximum = 100d;
    private double _value = 0d;

    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public Color BarColor { get; set; } = UiTheme.Accent;

    public GameProgressBar()
    {
        SetStyle(
            ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer |
            ControlStyles.UserPaint |
            ControlStyles.ResizeRedraw,
            true);

        BackColor = UiTheme.Surface;
        Height = 10;
        TabStop = false;
    }

    /// <summary>Sets the value range (defaults 0..100).</summary>
    public void Configure(double minimum, double maximum)
    {
        if (double.IsNaN(minimum) || double.IsNaN(maximum) || maximum <= minimum) return;
        _minimum = minimum;
        _maximum = maximum;
        Value = _value; // re-clamp and repaint
    }

    /// <summary>Clamped progress value; invalid values are ignored (no-op).</summary>
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public double Value
    {
        get => _value;
        set
        {
            if (double.IsNaN(value) || double.IsInfinity(value)) return;
            double clamped = Math.Clamp(value, _minimum, _maximum);
            if (clamped.Equals(_value)) return;
            _value = clamped;
            Invalidate();
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        var g = e.Graphics;
        var rect = ClientRectangle;
        if (rect.Width <= 0 || rect.Height <= 0 || _maximum <= _minimum) return;

        using (var track = new SolidBrush(UiTheme.Surface))
        {
            g.FillRectangle(track, rect);
        }

        double fraction = (_value - _minimum) / (_maximum - _minimum);
        int fillWidth = (int)Math.Round(rect.Width * Math.Clamp(fraction, 0d, 1d));
        if (fillWidth > 0)
        {
            using var bar = new SolidBrush(BarColor);
            g.FillRectangle(bar, 0, 0, fillWidth, rect.Height);
        }

        using var border = new Pen(UiTheme.Border);
        g.DrawRectangle(border, 0, 0, rect.Width - 1, rect.Height - 1);
    }
}
