using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using Lifestate;

namespace Lifestate;

/// <summary>
/// Game-style UI shell: persistent top status bar, four primary screens
/// (Life / Activities / People / More) switched by bottom navigation, More
/// subscreens (Character, Education, Save/Load, Settings), and a hidden F2
/// God Mode developer overlay. Presentation only — all gameplay mutations
/// go through existing controlled PlayerState APIs.
/// </summary>
public class MainForm : Form
{
    private readonly PlayerState _player;
    private readonly GameClock _clock;
    private readonly GodMode _godMode;
    private readonly System.Windows.Forms.Timer _timer;

    // ---- Shell ----
    private Label _lblClock = new();
    private Button _btnRunToggle = new();
    private Label _lblFeedback = new();
    private readonly Dictionary<string, Panel> _screens = new();
    private readonly Dictionary<string, UiTheme.GameNavButton> _navButtons = new();

    // ---- Life screen (single centered vertical life feed) ----
    private Panel _screenLife = new();
    private FlowLayoutPanel _lifeColumn = new();
    private Label _lifeFeedHeader = new();
    private Label _lifeEmptyLabel = new();
    private readonly List<Control> _timelineEntries = new();
    private Label _lblLifeAge = new();
    private Label _lblLifeStage = new();
    private Label _lblLifeMoney = new();
    private Label _lblLifeActivity = new();
    private Label _lblEnergyValue = new();
    private Label _lblHungerValue = new();
    private Label _lblThirstValue = new();
    private GameProgressBar _barEnergy = new();
    private GameProgressBar _barHunger = new();
    private GameProgressBar _barThirst = new();
    private UiTheme.BorderedPanel _pendingEventCard = new();
    private Label _lblPendingEventTitle = new();
    private Label _lblPendingEventDesc = new();
    private FlowLayoutPanel _pendingEventChoices = new();
    private FlowLayoutPanel _pendingEventFlow = new();
    private PendingLifeEvent? _lastRenderedEvent;
    private int _lastTimelineCount = -1;

    // ---- Activities screen ----
    private Panel _screenActivities = new();
    private UiTheme.BorderedPanel _heroCard = new();
    private Label _lblCurrentActivityName = new();
    private Label _lblCurrentActivityDetail = new();
    private UiTheme.BorderedPanel _progressCard = new();
    private Label _lblProgressHeader = new();
    private Label _lblProgressLine1 = new();
    private Label _lblProgressLine2 = new();
    private GameProgressBar _barActivityProgress = new();
    private FlowLayoutPanel _activitiesGrid = new();
    private readonly List<UiTheme.BorderedPanel> _activityCards = new();
    private string _lastActivityKey = "";

    // ---- People screen ----
    private Panel _screenPeople = new();
    private UiLayout.PersonCard _motherCard = new("M");
    private UiLayout.PersonCard _fatherCard = new("F");

    // ---- More + subscreens ----
    private Panel _screenMore = new();
    private Panel _screenCharacter = new();
    private FlowLayoutPanel _charLeft = new();
    private FlowLayoutPanel _charRight = new();
    private Label _lblCharAge = new();
    private Label _lblCharStage = new();
    private readonly Dictionary<string, Label> _charValues = new();
    private readonly Dictionary<string, GameProgressBar> _charBars = new();
    private Label _lblAcademics = new();
    private Label _lblAcademicsXp = new();
    private GameProgressBar _barAcademics = new();

    private Panel _screenEducation = new();
    private Label _lblEduTitle = new();
    private Label _lblEduGrade = new();
    private Label _lblEduProgress = new();
    private GameProgressBar _barEduProgress = new();
    private Label _lblEduYear = new();
    private Label _lblEduAcademics = new();
    private Label _lblEduStatus = new();
    private Button _btnEnroll = new();
    private Label _lblEduFeedback = new();

    private Panel _screenSaveLoad = new();
    private Label _lblSaveFeedback = new();

    private Panel _screenSettings = new();

    // ---- God Mode overlay ----
    private UiTheme.BorderedPanel _godModePanel = new();
    private Button _btnGodToggle = new();
    private bool _godModeVisible = false;

    private string _currentScreen = "life";

    public MainForm(PlayerState player, GameClock clock)
    {
        _player = player;
        _clock = clock;
        _godMode = new GodMode(clock, player);
        _timer = new System.Windows.Forms.Timer { Interval = 1000 };
        _timer.Tick += (s, e) =>
        {
            _clock.AdvanceSeconds(1);
            _player.AdvanceSimulation(GameClock.MinutesPerRealSecond);
            RefreshUI();
        };

        Text = "LIFESTATE";
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(1100, 720);
        MinimumSize = new Size(820, 600);
        BackColor = UiTheme.Background;
        DoubleBuffered = true;
        Font = UiTheme.FontBody;
        KeyPreview = true;
        KeyDown += (s, e) =>
        {
            if (e.KeyCode == Keys.F2)
            {
                ToggleGodMode();
                e.Handled = true;
            }
        };

        BuildShell();
        BuildLifeScreen();
        BuildActivitiesScreen();
        BuildPeopleScreen();
        BuildMoreScreen();
        BuildCharacterScreen();
        BuildEducationScreen();
        BuildSaveLoadScreen();
        BuildSettingsScreen();
        BuildGodModeOverlay();

        ShowScreen("life");
        RefreshUI();
    }

    // =====================================================================
    // SHELL
    // =====================================================================

    private void BuildShell()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 4,
            BackColor = UiTheme.Background
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, UiTheme.TopBarHeight));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, UiTheme.NavHeight));

        // Top status bar
        var topBar = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };
        topBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 55));
        topBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 45));
        var lblTitle = new Label
        {
            Text = "LIFESTATE",
            Font = UiTheme.FontTitle,
            ForeColor = UiTheme.TextPrimary,
            AutoSize = false,
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleLeft,
            Padding = new Padding(UiTheme.SpaceLg, 0, 0, 0),
            Margin = new Padding(0)
        };
        var rightCluster = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0),
            Padding = new Padding(0, 0, UiTheme.SpaceLg, 0)
        };
        rightCluster.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        rightCluster.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        _lblClock = new Label
        {
            Text = "Day 0   00:00",
            Font = UiTheme.FontValue,
            ForeColor = UiTheme.TextPrimary,
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleRight,
            Margin = new Padding(0)
        };
        _btnRunToggle = new Button { Text = "Paused", AutoSize = true, Margin = new Padding(10, 14, 0, 0) };
        UiTheme.ApplyStatusPillStyle(_btnRunToggle);
        _btnRunToggle.Click += (s, e) =>
        {
            if (_timer.Enabled) _timer.Stop(); else _timer.Start();
            RefreshTopBar();
        };
        rightCluster.Controls.Add(_lblClock, 0, 0);
        rightCluster.Controls.Add(_btnRunToggle, 1, 0);
        topBar.Controls.Add(lblTitle, 0, 0);
        topBar.Controls.Add(rightCluster, 1, 0);
        root.Controls.Add(topBar, 0, 0);

        // Screen host
        var screenHost = new Panel
        {
            Dock = DockStyle.Fill,
            BackColor = UiTheme.Background,
            Margin = new Padding(0),
            Padding = new Padding(0, UiTheme.SpaceMd, 0, UiTheme.SpaceSm)
        };
        _screens["life"] = _screenLife;
        _screens["activities"] = _screenActivities;
        _screens["people"] = _screenPeople;
        _screens["more"] = _screenMore;
        _screens["character"] = _screenCharacter;
        _screens["education"] = _screenEducation;
        _screens["saveload"] = _screenSaveLoad;
        _screens["settings"] = _screenSettings;
        foreach (var screen in _screens.Values)
        {
            screen.Dock = DockStyle.Fill;
            screen.BackColor = UiTheme.Background;
            screen.Visible = false;
            screenHost.Controls.Add(screen);
        }
        root.Controls.Add(screenHost, 0, 1);

        // Feedback + muted developer hint line
        var feedbackBar = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            BackColor = UiTheme.Background,
            Margin = new Padding(0),
            Padding = new Padding(UiTheme.SpaceLg, 0, UiTheme.SpaceLg, 0)
        };
        feedbackBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 70));
        feedbackBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30));
        _lblFeedback = new Label
        {
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleLeft,
            Font = UiTheme.FontSmall,
            ForeColor = UiTheme.TextSecondary,
            BackColor = UiTheme.Background,
            Text = "",
            Margin = new Padding(0)
        };
        var devHint = new Label
        {
            Text = "F2 · God Mode",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleRight,
            Font = UiTheme.FontSmall,
            ForeColor = UiTheme.TextMuted,
            BackColor = UiTheme.Background,
            Margin = new Padding(0)
        };
        feedbackBar.Controls.Add(_lblFeedback, 0, 0);
        feedbackBar.Controls.Add(devHint, 1, 0);
        root.Controls.Add(feedbackBar, 0, 2);

        // Bottom navigation
        var navBar = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 4,
            BackColor = UiTheme.Background,
            Padding = new Padding(8, 6, 8, 8),
            Margin = new Padding(0)
        };
        for (int i = 0; i < 4; i++) navBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 25));
        var navDefs = new (string key, string label)[]
        {
            ("life", "LIFE"),
            ("activities", "ACTIVITIES"),
            ("people", "PEOPLE"),
            ("more", "MORE")
        };
        foreach (var (key, label) in navDefs)
        {
            var btn = new UiTheme.GameNavButton { Text = label, Dock = DockStyle.Fill, Margin = new Padding(2, 0, 2, 0) };
            btn.Click += (s, e) => ShowScreen(key);
            _navButtons[key] = btn;
            navBar.Controls.Add(btn);
        }
        root.Controls.Add(navBar, 0, 3);

        Controls.Add(root);
    }

    private void ShowScreen(string key)
    {
        foreach (var screen in _screens.Values) screen.Visible = false;
        if (_screens.TryGetValue(key, out var panel)) panel.Visible = true;

        string navKey = key is "life" or "activities" or "people" or "more" ? key : "more";
        foreach (var pair in _navButtons)
        {
            pair.Value.Selected = pair.Key == navKey;
        }

        _currentScreen = key;
        RefreshUI();
    }

    private void SetFeedback(string text, Color color)
    {
        _lblFeedback.Text = text;
        _lblFeedback.ForeColor = color;
    }

    private void SetFeedback(string text) => SetFeedback(text, UiTheme.TextSecondary);

    private static FlowLayoutPanel CreateScreenFlow()
    {
        return new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoScroll = true,
            BackColor = UiTheme.Background,
            Margin = new Padding(0)
        };
    }

    /// <summary>Two-column centered body (Life, Character): capped width, independent scrolling columns.</summary>
    private static Panel CreateTwoColumnBody(int maxWidth, int leftPercent, out FlowLayoutPanel left, out FlowLayoutPanel right)
    {
        var host = new Panel { Dock = DockStyle.Fill, BackColor = UiTheme.Background, Margin = new Padding(0) };
        var table = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            BackColor = UiTheme.Background,
            Margin = new Padding(0)
        };
        table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, leftPercent));
        table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100 - leftPercent));
        left = CreateScreenFlow();
        left.Padding = new Padding(0, 0, UiTheme.SpaceMd, 0);
        right = CreateScreenFlow();
        table.Controls.Add(left, 0, 0);
        table.Controls.Add(right, 1, 0);
        host.Controls.Add(table);

        void Apply()
        {
            if (host.ClientSize.Width <= 0 || host.ClientSize.Height <= 0) return;
            int w = Math.Min(maxWidth, host.ClientSize.Width - UiTheme.SpaceLg * 2);
            w = Math.Max(380, w);
            table.SetBounds((host.ClientSize.Width - w) / 2, 0, w, host.ClientSize.Height);
        }
        host.Resize += (s, e) => Apply();
        if (host.Width > 0 && host.Height > 0) Apply();
        return host;
    }

    private void ToggleGodMode()
    {
        _godModeVisible = !_godModeVisible;
        _godMode.SetEnabled(_godModeVisible);
        _godModePanel.Visible = _godModeVisible;
    }

    // =====================================================================
    // LIFE SCREEN
    // =====================================================================

    /// <summary>
    /// Life reads as one centered vertical feed: a compact identity header, a
    /// compact needs section, an optional pending life event, then the dominant
    /// life-history feed flowing directly on the page background.
    /// </summary>
    private void BuildLifeScreen()
    {
        var host = UiLayout.CreateCenteredColumn(UiTheme.LifeContentMaxWidth, 30, out _lifeColumn);
        _screenLife.Controls.Add(host);

        // ---- Compact identity header: age/stage left, money/activity right.
        var headerCard = new UiTheme.BorderedPanel
        {
            Height = 100,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0, 0, 0, UiTheme.SpaceMd),
            Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceLg, UiTheme.SpaceMd)
        };
        var headerTable = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 1,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };
        headerTable.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        headerTable.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));

        var identityFlow = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };
        _lblLifeAge = new Label { Text = "Age 0", Font = UiTheme.FontLifeAge, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0) };
        _lblLifeStage = new Label { Text = "Infant", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(2, 0, 0, 0) };
        identityFlow.Controls.Add(_lblLifeAge);
        identityFlow.Controls.Add(_lblLifeStage);

        var statusTable = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };
        statusTable.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
        statusTable.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        _lblLifeMoney = new Label { Text = "$0", Font = UiTheme.FontValue, ForeColor = UiTheme.Positive, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleRight, Margin = new Padding(0) };
        _lblLifeActivity = new Label { Text = "Currently Idle", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleRight, Margin = new Padding(0) };
        statusTable.Controls.Add(_lblLifeMoney, 0, 0);
        statusTable.Controls.Add(_lblLifeActivity, 0, 1);

        headerTable.Controls.Add(identityFlow, 0, 0);
        headerTable.Controls.Add(statusTable, 1, 0);
        headerCard.Controls.Add(headerTable);
        _lifeColumn.Controls.Add(headerCard);
        UiLayout.TrackWidth(_lifeColumn, headerCard);

        // ---- Compact needs section (one section, three long readable bars).
        var needsCard = new UiTheme.BorderedPanel
        {
            Height = 144,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0, 0, 0, UiTheme.SpaceMd),
            Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceLg, UiTheme.SpaceMd)
        };
        var needsFlow = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };
        needsFlow.Controls.Add(UiTheme.CreateTag("NEEDS"));
        _barEnergy = new GameProgressBar { BarColor = UiTheme.Accent };
        _barHunger = new GameProgressBar { BarColor = UiTheme.Warning };
        _barThirst = new GameProgressBar { BarColor = UiTheme.AccentMuted };
        needsFlow.Controls.Add(CreateNeedRow("Energy", _barEnergy, _lblEnergyValue, needsFlow));
        needsFlow.Controls.Add(CreateNeedRow("Hunger", _barHunger, _lblHungerValue, needsFlow));
        needsFlow.Controls.Add(CreateNeedRow("Thirst", _barThirst, _lblThirstValue, needsFlow));
        needsCard.Controls.Add(needsFlow);
        _lifeColumn.Controls.Add(needsCard);
        UiLayout.TrackWidth(_lifeColumn, needsCard);

        // ---- Pending event: raised accent card, integrated above the feed.
        _pendingEventCard = new UiTheme.BorderedPanel
        {
            Height = 210,
            Margin = new Padding(0, 0, 0, UiTheme.SpaceMd),
            Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceLg, UiTheme.SpaceMd),
            Visible = false
        };
        _pendingEventCard.BorderColor = UiTheme.Accent;
        _pendingEventFlow = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            BackColor = UiTheme.SurfaceRaised,
            Margin = new Padding(0)
        };
        _pendingEventFlow.Controls.Add(UiTheme.CreateTag("LIFE EVENT", UiTheme.Accent));
        _lblPendingEventTitle = new Label { Text = "", Font = UiTheme.FontHeading, ForeColor = UiTheme.TextPrimary, AutoSize = true };
        _lblPendingEventDesc = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, UiTheme.SpaceXs, 0, UiTheme.SpaceSm) };
        _pendingEventChoices = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _pendingEventFlow.Controls.Add(_lblPendingEventTitle);
        _pendingEventFlow.Controls.Add(_lblPendingEventDesc);
        _pendingEventFlow.Controls.Add(_pendingEventChoices);

        // Choice buttons span the card so the pending event reads as the primary action.
        void SizeChoiceButtons()
        {
            int w = Math.Max(220, _pendingEventFlow.ClientSize.Width);
            foreach (Control choice in _pendingEventChoices.Controls) choice.Width = w;
        }
        _pendingEventFlow.Resize += (s, e) => SizeChoiceButtons();

        _pendingEventCard.Controls.Add(_pendingEventFlow);
        _lifeColumn.Controls.Add(_pendingEventCard);
        UiLayout.TrackWidth(_lifeColumn, _pendingEventCard);

        // ---- Life feed: heading plus entries flowing directly on the page.
        _lifeFeedHeader = new Label
        {
            Text = "LIFE",
            Font = UiTheme.FontHeading,
            ForeColor = UiTheme.TextPrimary,
            AutoSize = true,
            Margin = new Padding(0, UiTheme.SpaceSm, 0, UiTheme.SpaceSm)
        };
        _lifeColumn.Controls.Add(_lifeFeedHeader);

        _lifeEmptyLabel = new Label
        {
            Text = "Your life story is just beginning.",
            Font = UiTheme.FontBody,
            ForeColor = UiTheme.TextMuted,
            AutoSize = true,
            Margin = new Padding(UiTheme.SpaceXs, UiTheme.SpaceSm, 0, 0),
            Visible = false
        };
        _lifeColumn.Controls.Add(_lifeEmptyLabel);

        // Timeline entries track the column in one place (histories can grow large).
        _lifeColumn.Resize += (s, e) => FitTimelineEntries();
    }

    private void FitTimelineEntries()
    {
        int width = Math.Max(240, _lifeColumn.ClientSize.Width);
        foreach (var entry in _timelineEntries)
        {
            entry.Width = width - entry.Margin.Horizontal;
        }
    }

    private static TableLayoutPanel CreateNeedRow(string name, GameProgressBar bar, Label valueLabel, FlowLayoutPanel widthSource)
    {
        var row = new TableLayoutPanel
        {
            ColumnCount = 3,
            // Fixed height + explicit width: an auto-sized row would collapse the
            // percent bar column instead of stretching the gauge.
            AutoSize = false,
            Height = 24,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0, 2, 0, 2)
        };
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 76));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 44));

        row.Controls.Add(new Label { Text = name, Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 5, 0, 0) }, 0, 0);

        // Fill the middle column so bars read as long gauges rather than tiny chips.
        bar.Dock = DockStyle.Fill;
        bar.Margin = new Padding(0, 5, UiTheme.SpaceSm, 5);
        row.Controls.Add(bar, 1, 0);

        valueLabel.Text = "100";
        valueLabel.Font = UiTheme.FontSmall;
        valueLabel.ForeColor = UiTheme.TextPrimary;
        valueLabel.AutoSize = true;
        valueLabel.Margin = new Padding(0, 5, 0, 0);
        row.Controls.Add(valueLabel, 2, 0);

        void Apply() => row.Width = Math.Max(220, widthSource.ClientSize.Width - row.Margin.Horizontal - UiTheme.SpaceXs);
        widthSource.Resize += (s, e) => Apply();
        return row;
    }

    private void RefreshPendingEventCard()
    {
        var current = _player.Events.CurrentEvent;
        if (ReferenceEquals(current, _lastRenderedEvent))
        {
            return; // structure already correct
        }
        _lastRenderedEvent = current;

        _pendingEventChoices.Controls.Clear();
        if (current == null)
        {
            _pendingEventCard.Visible = false;
            return;
        }

        var definition = LifeEventCatalog.GetById(current.EventId);
        if (definition == null)
        {
            _pendingEventCard.Visible = false;
            return;
        }

        _lblPendingEventTitle.Text = definition.Title;
        _lblPendingEventDesc.Text = definition.Description;
        // Height follows the number of choices so the card never presumes a size.
        _pendingEventCard.Height = 124 + definition.Choices.Count * (UiTheme.ButtonHeight + UiTheme.SpaceSm);
        foreach (var choice in definition.Choices)
        {
            var captured = choice;
            var btn = new Button { Text = captured.Text, AutoSize = false, Height = UiTheme.ButtonHeight, Width = 320, Margin = new Padding(0, 0, 0, UiTheme.SpaceSm) };
            UiTheme.ApplyPrimaryButtonStyle(btn);
            btn.AutoSize = false;
            btn.Height = UiTheme.ButtonHeight;
            btn.Click += (s, e) =>
            {
                if (_player.ResolveEventChoice(captured.Id))
                {
                    SetFeedback("Choice made.", UiTheme.Positive);
                }
                else
                {
                    SetFeedback("That choice is no longer available.", UiTheme.Warning);
                }
                RefreshUI();
            };
            _pendingEventChoices.Controls.Add(btn);
        }
        _pendingEventCard.Visible = true;
    }

    /// <summary>
    /// Rebuilds the life-history feed only when the history actually changes, so
    /// the per-second refresh never resets scroll position or flickers. Entries
    /// flow directly in the page column beneath the LIFE heading, which keeps the
    /// feed dominant and avoids a giant empty timeline panel.
    /// </summary>
    private void RefreshTimeline()
    {
        if (_player.Events.History.Count == _lastTimelineCount)
        {
            return;
        }
        _lastTimelineCount = _player.Events.History.Count;

        _lifeColumn.SuspendLayout();
        foreach (var entry in _timelineEntries) _lifeColumn.Controls.Remove(entry);
        _timelineEntries.Clear();

        if (_player.Events.History.Count == 0)
        {
            _lifeEmptyLabel.Visible = true;
            _lifeColumn.ResumeLayout();
            return;
        }
        _lifeEmptyLabel.Visible = false;

        // Newest first; the newest entry carries the accent marker.
        int insertAt = _lifeColumn.Controls.GetChildIndex(_lifeFeedHeader) + 1;
        int width = Math.Max(240, _lifeColumn.ClientSize.Width);
        bool isFirst = true;
        foreach (var entry in _player.Events.History.Reverse())
        {
            var definition = LifeEventCatalog.GetById(entry.EventId);
            string title = definition?.Title ?? entry.EventId;
            string choiceText = definition?.Choices.FirstOrDefault(c => c.Id == entry.ChoiceId)?.Text ?? entry.ChoiceId;
            int age = (int)(entry.TriggeredDay / 365);

            var row = new UiLayout.TimelineEntry($"AGE {age}", title, choiceText, isFirst, onPage: true);
            row.Width = width - row.Margin.Horizontal;
            _lifeColumn.Controls.Add(row);
            _lifeColumn.Controls.SetChildIndex(row, insertAt++);
            _timelineEntries.Add(row);
            isFirst = false;
        }
        _lifeColumn.ResumeLayout();
    }

    // =====================================================================
    // ACTIVITIES SCREEN
    // =====================================================================

    private static readonly (string Name, string Description, string Key)[] ActivityDefs =
    {
        ("SLEEP", "Rest and restore your energy.", "sleep"),
        ("STUDY", "Improve your academic ability.", "study"),
        ("PLAY", "Have fun and develop through childhood.", "play"),
        ("FAMILY TIME", "Spend time with your parents.", "family"),
        ("WORK", "Earn money. Requires age 18.", "work")
    };

    private void BuildActivitiesScreen()
    {
        var host = UiLayout.CreateCenteredColumn(UiTheme.ContentMaxWidth, 30, out var column);
        _screenActivities.Controls.Add(host);

        column.Controls.Add(UiLayout.CreateScreenTitle("ACTIVITIES", "Continuous progression — the idle side of life."));

        // Current activity hero
        _heroCard = new UiTheme.BorderedPanel { Height = 168, Margin = new Padding(0, 0, 0, UiTheme.SpaceMd), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd) };
        var heroFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        heroFlow.Controls.Add(UiTheme.CreateTag("CURRENT ACTIVITY"));
        _lblCurrentActivityName = new Label { Text = "IDLE", Font = UiTheme.FontDisplay, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0) };
        _lblCurrentActivityDetail = new Label { Text = "Choose an activity below.", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, UiTheme.SpaceXs, 0, 0) };
        heroFlow.Controls.Add(_lblCurrentActivityName);
        heroFlow.Controls.Add(_lblCurrentActivityDetail);
        _heroCard.Controls.Add(heroFlow);
        column.Controls.Add(_heroCard);
        UiLayout.TrackWidth(column, _heroCard);

        // Activity progression card
        _progressCard = new UiTheme.BorderedPanel { Height = 168, Margin = new Padding(0, 0, 0, UiTheme.SpaceMd), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd), Visible = false };
        _progressCard.BorderColor = UiTheme.Accent;
        var progressFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _lblProgressHeader = UiTheme.CreateTag("", UiTheme.Accent);
        _barActivityProgress = new GameProgressBar { Height = 12, Margin = new Padding(0, 2, 0, UiTheme.SpaceSm), BarColor = UiTheme.Accent };
        _lblProgressLine1 = new Label { Text = "", Font = UiTheme.FontValue, ForeColor = UiTheme.TextPrimary, AutoSize = true };
        _lblProgressLine2 = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 2, 0, 0) };
        progressFlow.Controls.Add(_lblProgressHeader);
        progressFlow.Controls.Add(_barActivityProgress);
        progressFlow.Controls.Add(_lblProgressLine1);
        progressFlow.Controls.Add(_lblProgressLine2);
        _progressCard.Controls.Add(progressFlow);
        column.Controls.Add(_progressCard);
        UiLayout.TrackWidth(column, _progressCard);

        // Support actions strip (compact, secondary weight)
        var actionsCard = new UiTheme.BorderedPanel { Height = 58, Margin = new Padding(0, 0, 0, UiTheme.SpaceMd), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceSm, UiTheme.SpaceMd, UiTheme.SpaceSm) };
        var actionsFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        actionsFlow.Controls.Add(new Label { Text = "SUPPORT", Font = UiTheme.FontTag, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 10, UiTheme.SpaceMd, 0) });
        actionsFlow.Controls.Add(MakeActionButton("Wait 1 Hour", () =>
        {
            _clock.AdvanceSeconds(15);
            _player.AdvanceSimulation(60);
            RefreshUI();
        }));
        actionsFlow.Controls.Add(MakeActionButton("Eat +20", () => { _player.Eat(20); RefreshUI(); }));
        actionsFlow.Controls.Add(MakeActionButton("Drink +20", () => { _player.Drink(20); RefreshUI(); }));
        actionsCard.Controls.Add(actionsFlow);
        column.Controls.Add(actionsCard);
        UiLayout.TrackWidth(column, actionsCard);

        // Activity card grid
        column.Controls.Add(UiTheme.CreateTag("ALL ACTIVITIES"));
        _activitiesGrid = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = true,
            AutoSize = true,
            BackColor = UiTheme.Background,
            Margin = new Padding(0)
        };
        UiLayout.EnableCardSizing(_activitiesGrid, minCardWidth: 340, maxCardWidth: 560, gutter: UiTheme.SpaceSm);
        RebuildActivityCards();
        column.Controls.Add(_activitiesGrid);
        UiLayout.TrackWidth(column, _activitiesGrid);
    }

    private static Button MakeActionButton(string text, Action onClick)
    {
        var btn = new Button { Text = text, AutoSize = true, Margin = new Padding(0, 4, UiTheme.SpaceSm, 0) };
        UiTheme.ApplyUtilityButtonStyle(btn);
        btn.Click += (s, e) => onClick();
        return btn;
    }

    private void RebuildActivityCards()
    {
        _activitiesGrid.SuspendLayout();
        foreach (var card in _activityCards)
        {
            _activitiesGrid.Controls.Remove(card);
        }
        _activityCards.Clear();

        foreach (var def in ActivityDefs)
        {
            var card = new UiLayout.ActivityCard(def.Name, def.Description, def.Key);
            card.ActionButton.Click += (s, e) => HandleActivityButton(def.Key);
            _activityCards.Add(card);
            _activitiesGrid.Controls.Add(card);
        }
        _activitiesGrid.ResumeLayout();
    }

    private void HandleActivityButton(string key)
    {
        bool anyOtherActive =
            _player.IsSleeping || _player.IsWorking || _player.IsStudying ||
            _player.IsPlaying || _player.IsSpendingFamilyTime;

        switch (key)
        {
            case "sleep":
                if (_player.IsSleeping) { _player.StopSleeping(); }
                else if (anyOtherActive) { SetFeedback("You are busy with another activity.", UiTheme.Warning); }
                else { _player.StartSleeping(); }
                break;
            case "study":
                if (_player.IsStudying) { _player.StopStudying(); }
                else if (_player.Age < 6) { SetFeedback("You must be at least 6 to study.", UiTheme.Warning); }
                else if (anyOtherActive) { SetFeedback("You are busy with another activity.", UiTheme.Warning); }
                else { _player.StartStudying(); }
                break;
            case "play":
                if (_player.IsPlaying) { _player.StopPlaying(); }
                else if (_player.Age < 2) { SetFeedback("You must be at least 2 to play.", UiTheme.Warning); }
                else if (anyOtherActive) { SetFeedback("You are busy with another activity.", UiTheme.Warning); }
                else if (!_player.StartPlaying()) { SetFeedback("You are busy with another activity.", UiTheme.Warning); }
                break;
            case "family":
                if (_player.IsSpendingFamilyTime) { _player.StopFamilyTime(); }
                else if (anyOtherActive) { SetFeedback("You are busy with another activity.", UiTheme.Warning); }
                else if (!_player.StartFamilyTime()) { SetFeedback("You are busy with another activity.", UiTheme.Warning); }
                break;
            case "work":
                if (_player.IsWorking) { _player.StopWorking(); }
                else if (_player.Age < 18) { SetFeedback("You must be at least 18 to work.", UiTheme.Warning); }
                else if (anyOtherActive) { SetFeedback("You are busy with another activity.", UiTheme.Warning); }
                else { _player.StartWorking(); }
                break;
        }

        RefreshUI();
    }

    private static string CurrentActivityName(PlayerState player)
    {
        if (player.IsSleeping) return "Sleeping";
        if (player.IsWorking) return "Working";
        if (player.IsStudying) return "Studying";
        if (player.IsPlaying) return "Playing";
        if (player.IsSpendingFamilyTime) return "Family Time";
        return "Idle";
    }

    private void RefreshActivityCards()
    {
        string key = $"{_player.IsSleeping}|{_player.IsWorking}|{_player.IsStudying}|{_player.IsPlaying}|{_player.IsSpendingFamilyTime}";
        if (key != _lastActivityKey)
        {
            _lastActivityKey = key;
            RebuildActivityCards();
        }

        foreach (var card in _activityCards)
        {
            if (card.Tag is not (Label status, Button btn, string rowKey)) continue;

            bool isActive = rowKey switch
            {
                "sleep" => _player.IsSleeping,
                "study" => _player.IsStudying,
                "play" => _player.IsPlaying,
                "family" => _player.IsSpendingFamilyTime,
                "work" => _player.IsWorking,
                _ => false
            };

            if (isActive)
            {
                status.Text = "● ACTIVE";
                status.ForeColor = UiTheme.Accent;
                btn.Text = "Stop";
                UiTheme.ApplyDangerButtonStyle(btn);
                card.BorderColor = UiTheme.Accent;
            }
            else
            {
                status.Text = rowKey switch
                {
                    "work" => "Age 18+",
                    "study" => "Age 6+",
                    "play" => "Age 2+",
                    _ => "Available"
                };
                status.ForeColor = UiTheme.TextMuted;
                btn.Text = "Start";
                UiTheme.ApplySecondaryButtonStyle(btn);
                card.BorderColor = UiTheme.Border;
            }
        }
    }

    private void RefreshCurrentActivityHero()
    {
        string name = CurrentActivityName(_player);
        _lblLifeActivity.Text = name == "Idle" ? "Currently Idle" : $"Currently {name}";
        _lblCurrentActivityName.Text = name.ToUpperInvariant();

        if (name == "Idle")
        {
            _lblCurrentActivityDetail.Text = "Choose an activity below.";
            _heroCard.BorderColor = UiTheme.Border;
        }
        else
        {
            _lblCurrentActivityDetail.Text = "Time keeps moving while you work.";
            _heroCard.BorderColor = UiTheme.Accent;
        }
    }

    private void RefreshActivityProgressCard()
    {
        void Hide()
        {
            _progressCard.Visible = false;
        }

        if (_player.IsStudying)
        {
            _progressCard.Visible = true;
            _lblProgressHeader.Text = "STUDY PROGRESSION";
            _barActivityProgress.Visible = true;
            _barActivityProgress.Configure(0, SkillProgress.MaxExperience);
            _barActivityProgress.Value = _player.Skills.Academics.Experience;
            _lblProgressLine1.Text = $"Academics — Level {_player.Skills.Academics.Level}";
            string educationPart = _player.Education.Status == EducationStatus.PrimarySchool
                ? $"    Education: {_player.Education.EducationProgress}/100"
                : "";
            _lblProgressLine2.Text = $"{_player.Skills.Academics.Experience:N0} / {SkillProgress.MaxExperience:N0} XP    Study XP: {_player.StudyXP:N0}{educationPart}";
        }
        else if (_player.IsPlaying)
        {
            _progressCard.Visible = true;
            _lblProgressHeader.Text = "PLAY";
            _barActivityProgress.Visible = false;
            _lblProgressLine1.Text = $"Play hours (lifetime): {_player.TotalPlayHours:N0}";
            _lblProgressLine2.Text = "Playing builds fitness, creativity and confidence.";
        }
        else if (_player.IsSpendingFamilyTime)
        {
            _progressCard.Visible = true;
            _lblProgressHeader.Text = "FAMILY TIME";
            _barActivityProgress.Visible = false;
            _lblProgressLine1.Text = $"Mother {_player.Relationships.MotherRelationship.Closeness:F1}    Father {_player.Relationships.FatherRelationship.Closeness:F1}";
            _lblProgressLine2.Text = "Closeness grows for both parents each hour.";
        }
        else if (_player.IsWorking)
        {
            _progressCard.Visible = true;
            _lblProgressHeader.Text = "WORK";
            _barActivityProgress.Visible = false;
            _lblProgressLine1.Text = $"Money: {_player.Money:N0}";
            _lblProgressLine2.Text = "You earn $10 for every hour worked.";
        }
        else if (_player.IsSleeping)
        {
            _progressCard.Visible = true;
            _lblProgressHeader.Text = "SLEEP";
            _barActivityProgress.Visible = true;
            _barActivityProgress.Configure(0, 100);
            _barActivityProgress.Value = _player.Energy;
            _lblProgressLine1.Text = $"Energy {_player.Energy}";
            _lblProgressLine2.Text = "Sleeping restores energy over time.";
        }
        else
        {
            Hide();
        }
    }

    // =====================================================================
    // PEOPLE SCREEN
    // =====================================================================

    private void BuildPeopleScreen()
    {
        var host = UiLayout.CreateCenteredColumn(UiTheme.ContentMaxWidth, 30, out var column);
        _screenPeople.Controls.Add(host);

        column.Controls.Add(UiLayout.CreateScreenTitle("PEOPLE", "Your social world."));

        column.Controls.Add(UiTheme.CreateTag("FAMILY"));
        var familyRow = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = true,
            AutoSize = true,
            BackColor = UiTheme.Background,
            Margin = new Padding(0, 0, 0, UiTheme.SpaceMd)
        };
        UiLayout.EnableCardSizing(familyRow, minCardWidth: 320, maxCardWidth: 430, gutter: UiTheme.SpaceSm);
        familyRow.Controls.Add(_motherCard);
        familyRow.Controls.Add(_fatherCard);
        column.Controls.Add(familyRow);
        UiLayout.TrackWidth(column, familyRow);

        var friendsCard = new UiTheme.BorderedPanel { Height = 76, Margin = new Padding(0, 0, 0, 0), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceSm, UiTheme.SpaceMd, UiTheme.SpaceSm) };
        var friendsFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        friendsFlow.Controls.Add(UiTheme.CreateTag("FRIENDS"));
        friendsFlow.Controls.Add(new Label { Text = "You haven't made any friends yet.", Font = UiTheme.FontBody, ForeColor = UiTheme.TextMuted, AutoSize = true });
        friendsCard.Controls.Add(friendsFlow);
        column.Controls.Add(friendsCard);
        UiLayout.TrackWidth(column, friendsCard);
    }

    private void RefreshPeopleScreen()
    {
        _motherCard.NameLabel.Text = _player.Family.Mother.Name;
        _motherCard.RoleTag.Text = "MOTHER";
        _motherCard.InfoLabel.Text = $"Age {_player.Family.Mother.GetAge(_clock)}";
        _motherCard.ClosenessValue.Text = $"Closeness  {_player.Relationships.MotherRelationship.Closeness:F1}";
        _motherCard.ClosenessBar.Configure(0, 100);
        _motherCard.ClosenessBar.Value = _player.Relationships.MotherRelationship.Closeness;

        _fatherCard.NameLabel.Text = _player.Family.Father.Name;
        _fatherCard.RoleTag.Text = "FATHER";
        _fatherCard.InfoLabel.Text = $"Age {_player.Family.Father.GetAge(_clock)}";
        _fatherCard.ClosenessValue.Text = $"Closeness  {_player.Relationships.FatherRelationship.Closeness:F1}";
        _fatherCard.ClosenessBar.Configure(0, 100);
        _fatherCard.ClosenessBar.Value = _player.Relationships.FatherRelationship.Closeness;
    }

    // =====================================================================
    // MORE + SUBSCREENS
    // =====================================================================

    private void BuildMoreScreen()
    {
        var host = UiLayout.CreateCenteredColumn(UiTheme.ContentMaxWidth, 30, out var column);
        _screenMore.Controls.Add(host);

        column.Controls.Add(UiLayout.CreateScreenTitle("MORE", "Character, records, and settings."));

        var menuGrid = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = true,
            AutoSize = true,
            BackColor = UiTheme.Background,
            Margin = new Padding(0)
        };
        UiLayout.EnableCardSizing(menuGrid, minCardWidth: 300, maxCardWidth: 560, gutter: UiTheme.SpaceSm);
        menuGrid.Controls.Add(new UiLayout.MenuCard("CHARACTER", "Attributes, traits, and skills", () => ShowScreen("character")));
        menuGrid.Controls.Add(new UiLayout.MenuCard("EDUCATION", "School and academic progress", () => ShowScreen("education")));
        menuGrid.Controls.Add(new UiLayout.MenuCard("SAVE / LOAD", "Manage game data", () => ShowScreen("saveload")));
        menuGrid.Controls.Add(new UiLayout.MenuCard("SETTINGS", "Interface and game preferences", () => ShowScreen("settings")));
        column.Controls.Add(menuGrid);
        UiLayout.TrackWidth(column, menuGrid);
    }

    private void BuildCharacterScreen()
    {
        var bodyHost = CreateTwoColumnBody(UiTheme.ContentMaxWidth, 50, out _charLeft, out _charRight);

        var host = new Panel { Dock = DockStyle.Fill, BackColor = UiTheme.Background, Margin = new Padding(0) };
        var headerHost = UiLayout.CreateCenteredColumn(UiTheme.ContentMaxWidth, 30, out var headerColumn);
        headerColumn.Controls.Add(UiLayout.CreateScreenTitle("CHARACTER", "Your character sheet."));
        headerColumn.Height = 70;
        headerHost.Height = 70;
        headerHost.Dock = DockStyle.Top;
        bodyHost.Dock = DockStyle.Fill;
        host.Controls.Add(bodyHost);
        host.Controls.Add(headerHost);
        _screenCharacter.Controls.Add(host);

        // LEFT: identity + attributes
        var identityCard = new UiTheme.BorderedPanel { Height = 116, Margin = new Padding(0, 0, 0, UiTheme.SpaceMd), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd) };
        var identityFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _lblCharAge = new Label { Text = "Age 0", Font = UiTheme.FontDisplay, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0) };
        _lblCharStage = new Label { Text = "Infant", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(2, 0, 0, 0) };
        identityFlow.Controls.Add(_lblCharAge);
        identityFlow.Controls.Add(_lblCharStage);
        identityCard.Controls.Add(identityFlow);
        _charLeft.Controls.Add(identityCard);
        UiLayout.TrackWidth(_charLeft, identityCard);

        _charLeft.Controls.Add(UiTheme.CreateTag("ATTRIBUTES"));
        AddStatRows(_charLeft, new[] { "Intelligence", "Fitness", "Social", "Discipline", "Creativity" });

        // RIGHT: traits + skills
        _charRight.Controls.Add(UiTheme.CreateTag("TRAITS"));
        AddStatRows(_charRight, new[] { "Confidence", "Curiosity", "Patience", "Ambition", "Empathy" });

        _charRight.Controls.Add(UiTheme.CreateTag("SKILLS"));
        var skillCard = new UiTheme.BorderedPanel { Height = 128, Margin = new Padding(0, 0, 0, UiTheme.SpaceMd), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd) };
        var skillFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _lblAcademics = new Label { Text = "Academics — Level 0", Font = UiTheme.FontValue, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0, 0, 0, UiTheme.SpaceSm) };
        _barAcademics = new GameProgressBar { Height = 10, Width = 360, Margin = new Padding(0, 0, 0, UiTheme.SpaceXs) };
        _lblAcademicsXp = new Label { Text = "", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 0, 0, 0) };
        skillFlow.Controls.Add(_lblAcademics);
        skillFlow.Controls.Add(_barAcademics);
        UiLayout.TrackWidth(skillFlow, _barAcademics);
        skillFlow.Controls.Add(_lblAcademicsXp);
        skillCard.Controls.Add(skillFlow);
        _charRight.Controls.Add(skillCard);
        UiLayout.TrackWidth(_charRight, skillCard);
    }

    private void AddStatRows(FlowLayoutPanel flow, string[] names)
    {
        foreach (var name in names)
        {
            var valueLabel = new Label();
            var bar = new GameProgressBar { Height = 8 };
            _charValues[name] = valueLabel;
            _charBars[name] = bar;

            var row = new TableLayoutPanel
            {
                ColumnCount = 3,
                AutoSize = true,
                BackColor = UiTheme.Background,
                Margin = new Padding(0, 2, 0, 2)
            };
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 116));
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 64));
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

            row.Controls.Add(new Label { Text = name, Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(UiTheme.SpaceXs, 6, 0, 0) }, 0, 0);

            valueLabel.Text = "0";
            valueLabel.Font = UiTheme.FontBodyBold;
            valueLabel.ForeColor = UiTheme.TextPrimary;
            valueLabel.AutoSize = true;
            valueLabel.Margin = new Padding(0, 6, 0, 0);
            row.Controls.Add(valueLabel, 1, 0);

            bar.Margin = new Padding(UiTheme.SpaceSm, 10, 0, 0);
            bar.Width = 180;
            row.Controls.Add(bar, 2, 0);

            void Apply() => row.Width = Math.Max(240, flow.ClientSize.Width - row.Margin.Horizontal - UiTheme.SpaceXs);
            flow.Resize += (s, e) => Apply();
            flow.Controls.Add(row);
            Apply();
        }
    }

    private void RefreshCharacterScreen()
    {
        _lblCharAge.Text = $"Age {_player.Age}";
        _lblCharStage.Text = _player.LifeStage.ToString();

        foreach (var pair in _charBars)
        {
            pair.Value.Configure(0, 100);
        }
        _charValues["Intelligence"].Text = FormatStat(_player.Attributes.Intelligence);
        _charValues["Fitness"].Text = FormatStat(_player.Attributes.Fitness);
        _charValues["Social"].Text = FormatStat(_player.Attributes.Social);
        _charValues["Discipline"].Text = FormatStat(_player.Attributes.Discipline);
        _charValues["Creativity"].Text = FormatStat(_player.Attributes.Creativity);
        _charValues["Confidence"].Text = FormatStat(_player.Traits.Confidence);
        _charValues["Curiosity"].Text = FormatStat(_player.Traits.Curiosity);
        _charValues["Patience"].Text = FormatStat(_player.Traits.Patience);
        _charValues["Ambition"].Text = FormatStat(_player.Traits.Ambition);
        _charValues["Empathy"].Text = FormatStat(_player.Traits.Empathy);

        _charBars["Intelligence"].Value = _player.Attributes.Intelligence;
        _charBars["Fitness"].Value = _player.Attributes.Fitness;
        _charBars["Social"].Value = _player.Attributes.Social;
        _charBars["Discipline"].Value = _player.Attributes.Discipline;
        _charBars["Creativity"].Value = _player.Attributes.Creativity;
        _charBars["Confidence"].Value = _player.Traits.Confidence;
        _charBars["Curiosity"].Value = _player.Traits.Curiosity;
        _charBars["Patience"].Value = _player.Traits.Patience;
        _charBars["Ambition"].Value = _player.Traits.Ambition;
        _charBars["Empathy"].Value = _player.Traits.Empathy;

        _lblAcademics.Text = $"Academics — Level {_player.Skills.Academics.Level}";
        _lblAcademicsXp.Text = $"{_player.Skills.Academics.Experience:N0} / {SkillProgress.MaxExperience:N0} XP";
        _barAcademics.Configure(0, SkillProgress.MaxExperience);
        _barAcademics.Value = _player.Skills.Academics.Experience;
    }

    private static string FormatStat(double value) => value.ToString("F1");

    private void BuildEducationScreen()
    {
        var host = UiLayout.CreateCenteredColumn(UiTheme.ContentMaxWidth, 30, out var column);
        _screenEducation.Controls.Add(host);

        column.Controls.Add(UiLayout.CreateScreenTitle("EDUCATION", "Formal learning and academic progress."));

        var card = new UiTheme.BorderedPanel { Height = 330, Margin = new Padding(0, 0, 0, 0), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd) };
        var cardFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };

        _lblEduTitle = new Label { Text = "PRIMARY SCHOOL", Font = UiTheme.FontHeading, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0, 0, 0, UiTheme.SpaceXs) };
        _lblEduGrade = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 0, 0, UiTheme.SpaceSm) };
        _lblEduProgress = new Label { Text = "Education Progress", Font = UiTheme.FontTag, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, UiTheme.SpaceSm, 0, 2) };
        _barEduProgress = new GameProgressBar { Height = 10, Width = 380, Margin = new Padding(0, 0, 0, UiTheme.SpaceSm) };
        _lblEduYear = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, UiTheme.SpaceXs, 0, 0) };
        _lblEduAcademics = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, UiTheme.SpaceXs, 0, 0) };
        _lblEduStatus = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, UiTheme.SpaceXs, 0, 0) };

        _btnEnroll = new Button { Text = "Enroll in Primary School", AutoSize = true, Margin = new Padding(0, UiTheme.SpaceMd, 0, 0) };
        UiTheme.ApplyPrimaryButtonStyle(_btnEnroll);
        _btnEnroll.Click += (s, e) =>
        {
            if (_player.Age < 6) { _lblEduFeedback.Text = "Must be at least age 6 to enroll."; _lblEduFeedback.ForeColor = UiTheme.Warning; }
            else if (_player.Education.Status == EducationStatus.PrimarySchool) { _lblEduFeedback.Text = "Already enrolled in Primary School."; _lblEduFeedback.ForeColor = UiTheme.Warning; }
            else if (_player.Education.Status == EducationStatus.CompletedPrimary) { _lblEduFeedback.Text = "Primary School already completed."; _lblEduFeedback.ForeColor = UiTheme.Warning; }
            else if (_player.EnrollPrimarySchool()) { _lblEduFeedback.Text = "Enrolled."; _lblEduFeedback.ForeColor = UiTheme.Positive; }
            else { _lblEduFeedback.Text = "Enrollment failed."; _lblEduFeedback.ForeColor = UiTheme.Negative; }
            RefreshUI();
        };

        _lblEduFeedback = new Label { Text = "", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, UiTheme.SpaceSm, 0, 0) };

        cardFlow.Controls.Add(_lblEduTitle);
        cardFlow.Controls.Add(_lblEduGrade);
        cardFlow.Controls.Add(_lblEduProgress);
        cardFlow.Controls.Add(_barEduProgress);
        cardFlow.Controls.Add(_lblEduYear);
        cardFlow.Controls.Add(_lblEduAcademics);
        cardFlow.Controls.Add(_lblEduStatus);
        cardFlow.Controls.Add(_btnEnroll);
        cardFlow.Controls.Add(_lblEduFeedback);
        UiLayout.TrackWidth(cardFlow, _barEduProgress);
        card.Controls.Add(cardFlow);
        column.Controls.Add(card);
        UiLayout.TrackWidth(column, card);
    }

    private void RefreshEducationScreen()
    {
        switch (_player.Education.Status)
        {
            case EducationStatus.NotEnrolled:
                _lblEduTitle.Text = "NO SCHOOL YET";
                _lblEduGrade.Text = "You are not enrolled in school.";
                _lblEduProgress.Text = "";
                _barEduProgress.Visible = false;
                _lblEduYear.Text = "";
                _lblEduAcademics.Text = "";
                _lblEduStatus.Text = "";
                _btnEnroll.Visible = true;
                break;

            case EducationStatus.PrimarySchool:
            {
                _lblEduTitle.Text = "PRIMARY SCHOOL";
                _lblEduGrade.Text = $"Grade {_player.Education.PrimaryGrade}";
                _barEduProgress.Visible = true;
                _barEduProgress.Configure(0, 100);
                _barEduProgress.Value = _player.Education.EducationProgress;
                _lblEduProgress.Text = $"EDUCATION PROGRESS   {_player.Education.EducationProgress} / 100";
                long elapsed = Math.Min(_clock.Day - _player.Education.SchoolYearStartDay, 365);
                _lblEduYear.Text = $"Academic Year — Day {elapsed} / 365";
                _lblEduAcademics.Text = $"Academics — Level {_player.Skills.Academics.Level}";
                _lblEduStatus.Text = "Currently enrolled";
                _btnEnroll.Visible = false;
                break;
            }

            case EducationStatus.CompletedPrimary:
                _lblEduTitle.Text = "PRIMARY SCHOOL COMPLETED";
                _lblEduGrade.Text = "You finished primary school.";
                _lblEduProgress.Text = "";
                _barEduProgress.Visible = false;
                _lblEduYear.Text = "";
                _lblEduAcademics.Text = $"Academics — Level {_player.Skills.Academics.Level}";
                _lblEduStatus.Text = "";
                _btnEnroll.Visible = false;
                break;
        }
    }

    private void BuildSaveLoadScreen()
    {
        var host = UiLayout.CreateCenteredColumn(UiTheme.ContentMaxWidth, 30, out var column);
        _screenSaveLoad.Controls.Add(host);

        column.Controls.Add(UiLayout.CreateScreenTitle("SAVE / LOAD", "Manage your game data."));

        var card = new UiTheme.BorderedPanel { Height = 210, Margin = new Padding(0, 0, 0, 0), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd) };
        var cardFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        cardFlow.Controls.Add(UiTheme.CreateTag("GAME DATA"));
        cardFlow.Controls.Add(new Label { Text = "Your progress is stored locally on this computer.", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 0, 0, UiTheme.SpaceMd) });

        var saveBtn = new Button { Text = "SAVE GAME", AutoSize = true, Margin = new Padding(0, 0, UiTheme.SpaceSm, 0) };
        UiTheme.ApplyPrimaryButtonStyle(saveBtn);
        saveBtn.Click += (s, e) =>
        {
            SaveManager.Save(_clock, _player);
            _lblSaveFeedback.Text = "Game saved.";
            _lblSaveFeedback.ForeColor = UiTheme.Positive;
        };

        var loadBtn = new Button { Text = "LOAD GAME", AutoSize = true, Margin = new Padding(0, 0, 0, 0) };
        UiTheme.ApplySecondaryButtonStyle(loadBtn);
        loadBtn.Click += (s, e) =>
        {
            if (SaveManager.Load(_clock, _player))
            {
                _lblSaveFeedback.Text = "Game loaded.";
                _lblSaveFeedback.ForeColor = UiTheme.Positive;
            }
            else
            {
                _lblSaveFeedback.Text = "Save could not be loaded.";
                _lblSaveFeedback.ForeColor = UiTheme.Negative;
            }
            RefreshUI();
        };

        var buttonRow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, WrapContents = false, AutoSize = true, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        buttonRow.Controls.Add(saveBtn);
        buttonRow.Controls.Add(loadBtn);
        cardFlow.Controls.Add(buttonRow);
        _lblSaveFeedback = new Label { Text = "", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, UiTheme.SpaceMd, 0, 0) };
        cardFlow.Controls.Add(_lblSaveFeedback);
        card.Controls.Add(cardFlow);
        column.Controls.Add(card);
        UiLayout.TrackWidth(column, card);
    }

    private void BuildSettingsScreen()
    {
        var host = UiLayout.CreateCenteredColumn(UiTheme.ContentMaxWidth, 30, out var column);
        _screenSettings.Controls.Add(host);

        column.Controls.Add(UiLayout.CreateScreenTitle("SETTINGS", "Interface and game preferences."));

        var card = new UiTheme.BorderedPanel { Height = 150, Margin = new Padding(0, 0, 0, 0), Padding = new Padding(UiTheme.SpaceLg, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd) };
        var cardFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        cardFlow.Controls.Add(UiTheme.CreateTag("INTERFACE"));
        cardFlow.Controls.Add(new Label { Text = "More settings will be available later.", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 0, 0, UiTheme.SpaceMd) });
        cardFlow.Controls.Add(new Label { Text = "F2 opens the developer God Mode overlay.", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextMuted, AutoSize = true });
        card.Controls.Add(cardFlow);
        column.Controls.Add(card);
        UiLayout.TrackWidth(column, card);
    }

    // =====================================================================
    // GOD MODE OVERLAY (F2) — top-right floating developer panel
    // =====================================================================

    private void BuildGodModeOverlay()
    {
        _godModePanel = new UiTheme.BorderedPanel
        {
            Width = 272,
            Height = 474,
            BackColor = UiTheme.Surface,
            Visible = false,
            Padding = new Padding(UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd, UiTheme.SpaceMd)
        };
        _godModePanel.BorderColor = UiTheme.Warning;

        var flow = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoScroll = true,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };

        flow.Controls.Add(new Label { Text = "DEVELOPER — GOD MODE", Font = UiTheme.FontSection, ForeColor = UiTheme.Warning, AutoSize = true, Margin = new Padding(0, 0, 0, UiTheme.SpaceXs) });
        flow.Controls.Add(new Label { Text = "Enabled · F2 to hide", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 0, 0, UiTheme.SpaceSm) });

        void AddGodButton(string text, Action action)
        {
            var btn = new Button { Text = text, Margin = new Padding(0, 0, 0, UiTheme.SpaceXs), Width = 224 };
            UiTheme.ApplySecondaryButtonStyle(btn);
            btn.Click += (s, e) => { action(); RefreshUI(); };
            flow.Controls.Add(btn);
        }

        AddGodButton("+1 Day", () => _godMode.AdvanceDays(1));
        AddGodButton("+1 Year", () => _godMode.AdvanceDays(365));
        AddGodButton("+10 Years", () => _godMode.AdvanceDays(3650));
        AddGodButton("+100 Money", () => _godMode.AddMoney(100));
        AddGodButton("Restore Needs", () => _godMode.RestoreNeeds());
        AddGodButton("Max Attributes", () => _godMode.MaxAttributes());
        AddGodButton("Max Skills", () => _godMode.MaxSkills());
        AddGodButton("Max Traits", () => _godMode.MaxTraits());

        var closeBtn = new Button { Text = "Close (F2)", Margin = new Padding(0, UiTheme.SpaceSm, 0, 0), Width = 224 };
        UiTheme.ApplyDangerButtonStyle(closeBtn);
        closeBtn.Click += (s, e) => { if (_godModeVisible) ToggleGodMode(); };
        flow.Controls.Add(closeBtn);

        _godModePanel.Controls.Add(flow);
        Controls.Add(_godModePanel);

        void PositionOverlay()
        {
            _godModePanel.Location = new Point(ClientSize.Width - _godModePanel.Width - UiTheme.SpaceMd, UiTheme.TopBarHeight + UiTheme.SpaceMd);
            _godModePanel.BringToFront();
        }
        Resize += (s, e) => PositionOverlay();
        PositionOverlay();
    }

    // =====================================================================
    // REFRESH
    // =====================================================================

    private void RefreshTopBar()
    {
        _lblClock.Text = $"Day {_clock.Day:N0}   {_clock.Hour:00}:{_clock.Minute:00}";
        if (_timer.Enabled)
        {
            _btnRunToggle.Text = "Running";
            _btnRunToggle.ForeColor = UiTheme.Positive;
        }
        else
        {
            _btnRunToggle.Text = "Paused";
            _btnRunToggle.ForeColor = UiTheme.TextSecondary;
        }
    }

    private void RefreshUI()
    {
        RefreshTopBar();

        _lblLifeAge.Text = $"Age {_player.Age}";
        _lblLifeStage.Text = _player.LifeStage.ToString();
        _lblLifeMoney.Text = $"${_player.Money:N0}";

        _lblEnergyValue.Text = _player.Energy.ToString();
        _lblHungerValue.Text = _player.Hunger.ToString();
        _lblThirstValue.Text = _player.Thirst.ToString();
        _barEnergy.Configure(0, 100);
        _barEnergy.Value = _player.Energy;
        _barHunger.Configure(0, 100);
        _barHunger.Value = _player.Hunger;
        _barThirst.Configure(0, 100);
        _barThirst.Value = _player.Thirst;

        RefreshPendingEventCard();
        RefreshTimeline();
        RefreshCurrentActivityHero();
        RefreshActivityCards();
        RefreshActivityProgressCard();
        RefreshPeopleScreen();
        RefreshCharacterScreen();
        RefreshEducationScreen();
    }
}
