using System;
using System.Drawing;
using System.Windows.Forms;
using Lifestate;

namespace Lifestate;

/// <summary>
/// Small reusable presentation helpers for the game screens: centered content
/// columns, screen titles, card grids, and composite cards. Presentation only.
/// </summary>
public static class UiLayout
{
    /// <summary>
    /// Creates a screen host containing one centered vertical content column
    /// capped at <paramref name="maxWidth"/>. Small windows use the available
    /// width; large windows center the column instead of stretching cards.
    /// </summary>
    public static Panel CreateCenteredColumn(int maxWidth, int horizontalPad, out FlowLayoutPanel content)
    {
        var host = new Panel { Dock = DockStyle.Fill, BackColor = UiTheme.Background, Margin = new Padding(0) };
        var column = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoScroll = true,
            BackColor = UiTheme.Background,
            Margin = new Padding(0),
            Padding = new Padding(0)
        };
        host.Controls.Add(column);

        void Apply()
        {
            if (host.ClientSize.Width <= 0 || host.ClientSize.Height <= 0) return;
            int w = Math.Min(maxWidth, host.ClientSize.Width - horizontalPad * 2);
            w = Math.Max(320, w);
            column.SetBounds((host.ClientSize.Width - w) / 2, 0, w, host.ClientSize.Height);
        }

        host.Resize += (s, e) => Apply();
        if (host.Width > 0 && host.Height > 0) Apply();
        content = column;
        return host;
    }

    /// <summary>Screen header: bold title plus muted subtitle.</summary>
    public static FlowLayoutPanel CreateScreenTitle(string title, string subtitle)
    {
        var flow = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoSize = true,
            BackColor = UiTheme.Background,
            Margin = new Padding(0, 0, 0, UiTheme.SpaceMd)
        };
        flow.Controls.Add(new Label
        {
            Text = title,
            Font = UiTheme.FontScreenTitle,
            ForeColor = UiTheme.TextPrimary,
            AutoSize = true,
            Margin = new Padding(0)
        });
        if (!string.IsNullOrEmpty(subtitle))
        {
            flow.Controls.Add(new Label
            {
                Text = subtitle,
                Font = UiTheme.FontBody,
                ForeColor = UiTheme.TextSecondary,
                AutoSize = true,
                Margin = new Padding(0, 2, 0, 0)
            });
        }
        return flow;
    }

    /// <summary>Stretches a flow child to the container width (minimum applied).</summary>
    public static void TrackWidth(Control container, Control child, int minWidth = 140)
    {
        void Apply()
        {
            int width = container.ClientSize.Width - child.Margin.Horizontal;
            child.Width = Math.Max(minWidth, width);
        }
        container.Resize += (s, e) => Apply();
        Apply();
    }

    /// <summary>
    /// Enables wrap-around card sizing on a horizontal card flow: two cards per
    /// row when there is room, one otherwise, capped at <paramref name="maxCardWidth"/>.
    /// </summary>
    public static void EnableCardSizing(FlowLayoutPanel grid, int minCardWidth, int maxCardWidth, int gutter)
    {
        void Apply()
        {
            if (grid.ClientSize.Width <= 0) return;
            int available = grid.ClientSize.Width - gutter;
            bool twoColumns = available >= minCardWidth * 2 + gutter;
            int cardWidth = twoColumns ? (available - gutter) / 2 : available;
            cardWidth = Math.Min(cardWidth, maxCardWidth);
            foreach (Control child in grid.Controls)
            {
                child.Width = Math.Max(minCardWidth, cardWidth);
            }
        }
        grid.Resize += (s, e) => Apply();
        grid.ControlAdded += (s, e) => Apply();
    }

    /// <summary>
    /// One resolved life event in the timeline feed: vertical guide rail with a
    /// dot marker, age tag, event title, and muted outcome text.
    /// </summary>
    public sealed class TimelineEntry : Panel
    {
        private readonly bool _isNewest;

        public TimelineEntry(string ageText, string title, string choiceText, bool isNewest)
        {
            _isNewest = isNewest;
            BackColor = UiTheme.SurfaceRaised;
            Height = 84;
            Margin = new Padding(0, 0, 0, UiTheme.SpaceXs);
            Padding = new Padding(30, 10, UiTheme.SpaceSm, UiTheme.SpaceSm);

            var flow = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                BackColor = UiTheme.SurfaceRaised,
                Margin = new Padding(0)
            };
            flow.Controls.Add(new Label
            {
                Text = ageText,
                Font = UiTheme.FontTag,
                ForeColor = UiTheme.TextMuted,
                AutoSize = true,
                Margin = new Padding(0)
            });
            flow.Controls.Add(new Label
            {
                Text = title,
                Font = UiTheme.FontBodyBold,
                ForeColor = UiTheme.TextPrimary,
                AutoSize = true,
                Margin = new Padding(0, 1, 0, 0)
            });
            flow.Controls.Add(new Label
            {
                Text = choiceText,
                Font = UiTheme.FontSmall,
                ForeColor = UiTheme.TextSecondary,
                AutoSize = true,
                Margin = new Padding(0, 1, 0, 0)
            });
            Controls.Add(flow);

            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            var g = e.Graphics;
            using var rail = new Pen(UiTheme.Border);
            g.DrawLine(rail, 11, 0, 11, Height);
            using var dot = new SolidBrush(_isNewest ? UiTheme.Accent : UiTheme.TextMuted);
            g.FillEllipse(dot, 7, 26, 9, 9);
        }
    }

    /// <summary>
    /// Large relationship card: placeholder portrait block, role tag, name,
    /// age, and closeness bar with numeric value.
    /// </summary>
    public sealed class PersonCard : UiTheme.BorderedPanel
    {
        public Label RoleTag = new();
        public Label NameLabel = new();
        public Label InfoLabel = new();
        public Label ClosenessValue = new();
        public GameProgressBar ClosenessBar = new();

        public PersonCard(string initial)
        {
            Height = 176;
            Margin = new Padding(0, 0, UiTheme.SpaceSm, UiTheme.SpaceSm);
            Padding = new Padding(UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd);

            var layout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                BackColor = UiTheme.SurfaceRaised,
                Margin = new Padding(0)
            };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 76));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

            var portrait = new UiTheme.BorderedPanel
            {
                Width = 68,
                Height = 68,
                Margin = new Padding(0, 4, 0, 0),
                BackColor = UiTheme.Surface
            };
            portrait.BorderColor = UiTheme.Accent;
            portrait.Controls.Add(new Label
            {
                Text = initial,
                Font = UiTheme.FontDisplay,
                ForeColor = UiTheme.Accent,
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleCenter,
                BackColor = UiTheme.Surface,
                Margin = new Padding(0)
            });
            layout.Controls.Add(portrait, 0, 0);

            var info = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                BackColor = UiTheme.SurfaceRaised,
                Margin = new Padding(10, 0, 0, 0)
            };
            RoleTag.Font = UiTheme.FontTag;
            RoleTag.ForeColor = UiTheme.TextMuted;
            RoleTag.AutoSize = true;
            RoleTag.Margin = new Padding(0, 2, 0, 2);

            NameLabel.Font = UiTheme.FontHeading;
            NameLabel.ForeColor = UiTheme.TextPrimary;
            NameLabel.AutoSize = true;
            NameLabel.Margin = new Padding(0, 0, 0, 1);

            InfoLabel.Font = UiTheme.FontBody;
            InfoLabel.ForeColor = UiTheme.TextSecondary;
            InfoLabel.AutoSize = true;
            InfoLabel.Margin = new Padding(0, 0, 0, UiTheme.SpaceSm);

            ClosenessValue.Font = UiTheme.FontSmall;
            ClosenessValue.ForeColor = UiTheme.TextPrimary;
            ClosenessValue.AutoSize = true;
            ClosenessValue.Margin = new Padding(0, 2, 0, 0);

            ClosenessBar.Height = 8;
            ClosenessBar.Width = 240;
            ClosenessBar.Margin = new Padding(0, 2, 0, 0);

            info.Controls.Add(RoleTag);
            info.Controls.Add(NameLabel);
            info.Controls.Add(InfoLabel);
            info.Controls.Add(ClosenessBar);
            info.Controls.Add(ClosenessValue);
            layout.Controls.Add(info, 1, 0);

            Controls.Add(layout);
        }
    }

    /// <summary>
    /// Game-like activity card: name, description, availability/status line and
    /// a Start/Stop button. Accent border when active. Tag = (status, button, key).
    /// </summary>
    public sealed class ActivityCard : UiTheme.BorderedPanel
    {
        public Label StatusLabel = new();
        public Button ActionButton = new();

        public ActivityCard(string name, string description, string key)
        {
            Height = 118;
            Margin = new Padding(0, 0, UiTheme.SpaceSm, UiTheme.SpaceSm);
            Padding = new Padding(UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd);

            var flow = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                BackColor = UiTheme.SurfaceRaised,
                Margin = new Padding(0)
            };
            flow.Controls.Add(new Label
            {
                Text = name,
                Font = UiTheme.FontBodyBold,
                ForeColor = UiTheme.TextPrimary,
                AutoSize = true,
                Margin = new Padding(0, 2, 0, 1)
            });
            flow.Controls.Add(new Label
            {
                Text = description,
                Font = UiTheme.FontSmall,
                ForeColor = UiTheme.TextSecondary,
                AutoSize = true,
                Margin = new Padding(0, 0, 0, UiTheme.SpaceSm)
            });

            var row = new TableLayoutPanel
            {
                ColumnCount = 2,
                AutoSize = true,
                BackColor = UiTheme.SurfaceRaised,
                Margin = new Padding(0)
            };
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 130));

            StatusLabel.Font = UiTheme.FontTag;
            StatusLabel.ForeColor = UiTheme.TextMuted;
            StatusLabel.Dock = DockStyle.Fill;
            StatusLabel.TextAlign = ContentAlignment.MiddleLeft;
            StatusLabel.Margin = new Padding(0);
            row.Controls.Add(StatusLabel, 0, 0);

            ActionButton.Text = "Start";
            ActionButton.Dock = DockStyle.Fill;
            ActionButton.Margin = new Padding(8, 0, 0, 0);
            UiTheme.ApplySecondaryButtonStyle(ActionButton);
            row.Controls.Add(ActionButton, 1, 0);

            flow.Controls.Add(row);
            Controls.Add(flow);
            Tag = (StatusLabel, ActionButton, key);
        }
    }

    /// <summary>Menu card for the More screen: title, description, click action.</summary>
    public sealed class MenuCard : UiTheme.BorderedPanel
    {
        public MenuCard(string title, string description, Action onClick)
        {
            Height = 88;
            Margin = new Padding(0, 0, UiTheme.SpaceSm, UiTheme.SpaceSm);
            Padding = new Padding(UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd);
            Cursor = Cursors.Hand;

            var flow = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                BackColor = UiTheme.SurfaceRaised,
                Margin = new Padding(0)
            };
            flow.Controls.Add(new Label
            {
                Text = title,
                Font = UiTheme.FontBodyBold,
                ForeColor = UiTheme.TextPrimary,
                AutoSize = true,
                Margin = new Padding(0, 2, 0, 2)
            });
            flow.Controls.Add(new Label
            {
                Text = description,
                Font = UiTheme.FontSmall,
                ForeColor = UiTheme.TextSecondary,
                AutoSize = true,
                Margin = new Padding(0, 0, 0, 0)
            });
            Controls.Add(flow);

            Click += (s, e) => onClick();
            flow.Click += (s, e) => onClick();
            foreach (Control child in flow.Controls)
            {
                child.Click += (s, e) => onClick();
            }
        }
    }
}
