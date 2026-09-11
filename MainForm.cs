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
    private readonly Dictionary<string, Button> _navButtons = new();

    // ---- Life screen ----
    private Panel _screenLife = new();
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
    private FlowLayoutPanel _timelineBody = new();
    private PendingLifeEvent? _lastRenderedEvent;
    private int _lastTimelineCount = -1;

    // ---- Activities screen ----
    private Panel _screenActivities = new();
    private Label _lblCurrentActivityName = new();
    private Label _lblCurrentActivityDetail = new();
    private UiTheme.BorderedPanel _progressCard = new();
    private Label _lblProgressHeader = new();
    private Label _lblProgressLine1 = new();
    private Label _lblProgressLine2 = new();
    private GameProgressBar _barActivityProgress = new();
    private FlowLayoutPanel _activitiesFlow = new();
    private readonly List<Control> _activityRowControls = new();
    private string _lastActivityKey = "";

    // ---- People screen ----
    private Panel _screenPeople = new();
    private Label _lblMotherName = new();
    private Label _lblMotherInfo = new();
    private Label _lblMotherCloseness = new();
    private GameProgressBar _barMotherCloseness = new();
    private Label _lblFatherName = new();
    private Label _lblFatherInfo = new();
    private Label _lblFatherCloseness = new();
    private GameProgressBar _barFatherCloseness = new();

    // ---- More + subscreens ----
    private Panel _screenMore = new();
    private Panel _screenCharacter = new();
    private Label _lblCharAgeStage = new();
    private Label _lblIntel = new();
    private Label _lblFitness = new();
    private Label _lblSocial = new();
    private Label _lblDiscipline = new();
    private Label _lblCreativity = new();
    private Label _lblConfidence = new();
    private Label _lblCuriosity = new();
    private Label _lblPatience = new();
    private Label _lblAmbition = new();
    private Label _lblEmpathy = new();
    private Label _lblAcademics = new();
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
    private Panel _godModePanel = new();
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

    private void ToggleGodMode()
    {
        _godModeVisible = !_godModeVisible;
        _godMode.SetEnabled(_godModeVisible);
        _godModePanel.Visible = _godModeVisible;
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
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 54));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 60));

        // Top status bar
        var topBar = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            BackColor = UiTheme.Surface,
            Padding = new Padding(20, 0, 20, 0),
            Margin = new Padding(0)
        };
        topBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 60));
        topBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 40));
        var lblTitle = new Label
        {
            Text = "LIFESTATE",
            Font = UiTheme.FontTitle,
            ForeColor = UiTheme.TextPrimary,
            AutoSize = false,
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleLeft
        };
        var rightCluster = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.RightToLeft,
            Dock = DockStyle.Fill,
            WrapContents = false,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };
        _btnRunToggle = new Button
        {
            Text = "Paused",
            AutoSize = true,
            Margin = new Padding(10, 12, 0, 0)
        };
        UiTheme.ApplySecondaryButtonStyle(_btnRunToggle);
        _btnRunToggle.Click += (s, e) =>
        {
            if (_timer.Enabled) _timer.Stop(); else _timer.Start();
            RefreshTopBar();
        };
        _lblClock = new Label
        {
            Text = "Day 0   00:00",
            Font = UiTheme.FontBodyBold,
            ForeColor = UiTheme.TextPrimary,
            AutoSize = true,
            Margin = new Padding(0, 16, 4, 0)
        };
        rightCluster.Controls.Add(_btnRunToggle);
        rightCluster.Controls.Add(_lblClock);
        topBar.Controls.Add(lblTitle, 0, 0);
        topBar.Controls.Add(rightCluster, 1, 0);
        root.Controls.Add(topBar, 0, 0);

        // Screen host
        var screenHost = new Panel { Dock = DockStyle.Fill, BackColor = UiTheme.Background, Padding = new Padding(24, 14, 24, 6), Margin = new Padding(0) };
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

        // Global feedback line
        _lblFeedback = new Label
        {
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleLeft,
            Font = UiTheme.FontSmall,
            ForeColor = UiTheme.TextSecondary,
            BackColor = UiTheme.Background,
            Padding = new Padding(26, 0, 0, 0),
            Text = "",
            Margin = new Padding(0)
        };
        root.Controls.Add(_lblFeedback, 0, 2);

        // Bottom navigation
        var navBar = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 4,
            BackColor = UiTheme.Background,
            Padding = new Padding(8, 5, 8, 8),
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
            var btn = new Button { Text = label, Tag = key, Dock = DockStyle.Fill, Margin = new Padding(2, 0, 2, 0) };
            UiTheme.ApplyNavigationButtonStyle(btn);
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
            UiTheme.SetNavigationSelected(pair.Value, pair.Key == navKey);
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

    /// <summary>Keeps a flow child stretched to the flow width as the window resizes.</summary>
    private static void TrackWidth(FlowLayoutPanel flow, Control control, int extraShrink = 0)
    {
        void Apply()
        {
            int width = flow.ClientSize.Width - control.Margin.Horizontal - extraShrink;
            control.Width = Math.Max(140, width);
        }
        flow.Resize += (s, e) => Apply();
        Apply();
    }

    /// <summary>Creates a screen-content flow with vertical scrolling.</summary>
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

    // =====================================================================
    // LIFE SCREEN
    // =====================================================================

    private void BuildLifeScreen()
    {
        var columns = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            BackColor = UiTheme.Background,
            Margin = new Padding(0)
        };
        columns.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 52));
        columns.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 48));

        // LEFT column
        var left = CreateScreenFlow();
        columns.Controls.Add(left, 0, 0);

        var identityCard = new UiTheme.BorderedPanel { Height = 148, Margin = new Padding(0, 0, 10, 10), Padding = new Padding(18, 14, 18, 12) };
        var identityFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _lblLifeAge = new Label { Text = "Age 0", Font = UiTheme.FontTitle, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0, 0, 0, 0) };
        _lblLifeStage = new Label { Text = "Infant", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(2, 0, 0, 2) };
        _lblLifeMoney = new Label { Text = "$1,000", Font = UiTheme.FontHeading, ForeColor = UiTheme.Positive, AutoSize = true, Margin = new Padding(0, 6, 0, 0) };
        identityFlow.Controls.Add(_lblLifeAge);
        identityFlow.Controls.Add(_lblLifeStage);
        identityFlow.Controls.Add(_lblLifeMoney);
        identityCard.Controls.Add(identityFlow);
        left.Controls.Add(identityCard);
        TrackWidth(left, identityCard);

        var activityCard = new UiTheme.BorderedPanel { Height = 92, Margin = new Padding(0, 0, 10, 10), Padding = new Padding(18, 12, 18, 10) };
        var activityFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        activityFlow.Controls.Add(new Label { Text = "CURRENT ACTIVITY", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 0, 0, 4) });
        _lblLifeActivity = new Label { Text = "Idle", Font = UiTheme.FontHeading, ForeColor = UiTheme.TextPrimary, AutoSize = true };
        activityFlow.Controls.Add(_lblLifeActivity);
        activityCard.Controls.Add(activityFlow);
        left.Controls.Add(activityCard);
        TrackWidth(left, activityCard);

        var needsCard = new UiTheme.BorderedPanel { Height = 172, Margin = new Padding(0, 0, 10, 10), Padding = new Padding(18, 12, 18, 10) };
        var needsFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        needsFlow.Controls.Add(new Label { Text = "NEEDS", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 0, 0, 6) });
        _barEnergy = new GameProgressBar { BarColor = UiTheme.Accent };
        _barHunger = new GameProgressBar { BarColor = UiTheme.Warning };
        _barThirst = new GameProgressBar { BarColor = UiTheme.Warning };
        needsFlow.Controls.Add(CreateNeedRow("Energy", _barEnergy, _lblEnergyValue, needsFlow));
        needsFlow.Controls.Add(CreateNeedRow("Hunger", _barHunger, _lblHungerValue, needsFlow));
        needsFlow.Controls.Add(CreateNeedRow("Thirst", _barThirst, _lblThirstValue, needsFlow));
        needsCard.Controls.Add(needsFlow);
        left.Controls.Add(needsCard);
        TrackWidth(left, needsCard);

        // RIGHT column
        var right = CreateScreenFlow();
        columns.Controls.Add(right, 1, 0);

        _pendingEventCard = new UiTheme.BorderedPanel { Height = 236, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(18, 14, 18, 12), Visible = false };
        _pendingEventCard.BorderColor = UiTheme.Accent;
        var pendingFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        pendingFlow.Controls.Add(new Label { Text = "LIFE EVENT", Font = UiTheme.FontSection, ForeColor = UiTheme.Accent, AutoSize = true, Margin = new Padding(0, 0, 0, 6) });
        _lblPendingEventTitle = new Label { Text = "", Font = UiTheme.FontHeading, ForeColor = UiTheme.TextPrimary, AutoSize = true };
        _lblPendingEventDesc = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 4, 0, 6) };
        _pendingEventChoices = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        pendingFlow.Controls.Add(_lblPendingEventTitle);
        pendingFlow.Controls.Add(_lblPendingEventDesc);
        pendingFlow.Controls.Add(_pendingEventChoices);
        _pendingEventCard.Controls.Add(pendingFlow);
        right.Controls.Add(_pendingEventCard);
        TrackWidth(right, _pendingEventCard);

        var timelineCard = new UiTheme.BorderedPanel { Height = 430, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(18, 14, 18, 12) };
        _timelineBody = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _timelineBody.Controls.Add(new Label { Text = "LIFE TIMELINE", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 0, 0, 6) });
        timelineCard.Controls.Add(_timelineBody);
        right.Controls.Add(timelineCard);
        TrackWidth(right, timelineCard);

        _screenLife.Controls.Add(columns);
    }

    private static TableLayoutPanel CreateNeedRow(string name, GameProgressBar bar, Label valueLabel, FlowLayoutPanel widthSource)
    {
        var row = new TableLayoutPanel
        {
            ColumnCount = 3,
            AutoSize = true,
            BackColor = UiTheme.SurfaceRaised,
            Margin = new Padding(0, 2, 0, 2)
        };
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 76));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 44));

        row.Controls.Add(new Label { Text = name, Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 5, 0, 0) }, 0, 0);

        bar.Height = 12;
        bar.Margin = new Padding(0, 9, 8, 0);
        bar.Width = 200;
        row.Controls.Add(bar, 1, 0);

        valueLabel.Text = "100";
        valueLabel.Font = UiTheme.FontSmall;
        valueLabel.ForeColor = UiTheme.TextPrimary;
        valueLabel.AutoSize = true;
        valueLabel.Margin = new Padding(0, 6, 0, 0);
        row.Controls.Add(valueLabel, 2, 0);

        void Apply() => row.Width = Math.Max(220, widthSource.ClientSize.Width - row.Margin.Horizontal);
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
        foreach (var choice in definition.Choices)
        {
            var captured = choice;
            var btn = new Button { Text = captured.Text, AutoSize = true, Margin = new Padding(0, 2, 0, 2) };
            UiTheme.ApplyPrimaryButtonStyle(btn);
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

    private void RefreshTimeline()
    {
        if (_player.Events.History.Count == _lastTimelineCount)
        {
            return;
        }
        _lastTimelineCount = _player.Events.History.Count;

        // Clear everything except the section header (index 0).
        for (int i = _timelineBody.Controls.Count - 1; i >= 1; i--)
        {
            _timelineBody.Controls.RemoveAt(i);
        }

        if (_player.Events.History.Count == 0)
        {
            _timelineBody.Controls.Add(new Label
            {
                Text = "Your life story is just beginning.",
                Font = UiTheme.FontBody,
                ForeColor = UiTheme.TextMuted,
                AutoSize = true,
                Margin = new Padding(0, 4, 0, 0)
            });
            return;
        }

        // Newest first.
        foreach (var entry in _player.Events.History.Reverse())
        {
            var definition = LifeEventCatalog.GetById(entry.EventId);
            string title = definition?.Title ?? entry.EventId;
            string choiceText = definition?.Choices.FirstOrDefault(c => c.Id == entry.ChoiceId)?.Text ?? entry.ChoiceId;
            int age = (int)(entry.TriggeredDay / 365);

            _timelineBody.Controls.Add(new Label
            {
                Text = $"AGE {age}",
                Font = UiTheme.FontSmall,
                ForeColor = UiTheme.TextMuted,
                AutoSize = true,
                Margin = new Padding(0, 6, 0, 0)
            });
            _timelineBody.Controls.Add(new Label
            {
                Text = title,
                Font = UiTheme.FontBodyBold,
                ForeColor = UiTheme.TextPrimary,
                AutoSize = true,
                Margin = new Padding(0, 0, 0, 0)
            });
            _timelineBody.Controls.Add(new Label
            {
                Text = choiceText,
                Font = UiTheme.FontBody,
                ForeColor = UiTheme.TextSecondary,
                AutoSize = true,
                Margin = new Padding(0, 0, 0, 4)
            });
            var separator = new Panel { Height = 1, Width = 380, BackColor = UiTheme.Border, Margin = new Padding(0, 0, 0, 2) };
            TrackWidth(_timelineBody, separator);
            _timelineBody.Controls.Add(separator);
        }
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
        _activitiesFlow = CreateScreenFlow();
        _screenActivities.Controls.Add(_activitiesFlow);

        var currentCard = new UiTheme.BorderedPanel { Height = 104, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(18, 12, 18, 10) };
        var currentFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        currentFlow.Controls.Add(new Label { Text = "CURRENT ACTIVITY", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 0, 0, 4) });
        _lblCurrentActivityName = new Label { Text = "IDLE", Font = UiTheme.FontHeading, ForeColor = UiTheme.TextPrimary, AutoSize = true };
        _lblCurrentActivityDetail = new Label { Text = "You are currently idle.", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 2, 0, 0) };
        currentFlow.Controls.Add(_lblCurrentActivityName);
        currentFlow.Controls.Add(_lblCurrentActivityDetail);
        currentCard.Controls.Add(currentFlow);
        _activitiesFlow.Controls.Add(currentCard);
        TrackWidth(_activitiesFlow, currentCard);

        _progressCard = new UiTheme.BorderedPanel { Height = 150, Margin = new Padding(0, 0, 0, 12), Padding = new Padding(18, 12, 18, 10), Visible = false };
        _progressCard.BorderColor = UiTheme.Accent;
        var progressFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _lblProgressHeader = new Label { Text = "", Font = UiTheme.FontSection, ForeColor = UiTheme.Accent, AutoSize = true, Margin = new Padding(0, 0, 0, 6) };
        _barActivityProgress = new GameProgressBar { Height = 12, Width = 420, Margin = new Padding(0, 2, 0, 6), BarColor = UiTheme.Accent };
        _lblProgressLine1 = new Label { Text = "", Font = UiTheme.FontBodyBold, ForeColor = UiTheme.TextPrimary, AutoSize = true };
        _lblProgressLine2 = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 2, 0, 0) };
        progressFlow.Controls.Add(_lblProgressHeader);
        progressFlow.Controls.Add(_barActivityProgress);
        progressFlow.Controls.Add(_lblProgressLine1);
        progressFlow.Controls.Add(_lblProgressLine2);
        _progressCard.Controls.Add(progressFlow);
        _activitiesFlow.Controls.Add(_progressCard);
        TrackWidth(_activitiesFlow, _progressCard);

        // Immediate actions (existing gameplay, preserved)
        var actionsCard = new UiTheme.BorderedPanel { Height = 96, Margin = new Padding(0, 0, 0, 12), Padding = new Padding(18, 10, 18, 8) };
        var actionsFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        actionsFlow.Controls.Add(new Label { Text = "ACTIONS", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 10, 18, 0) });
        actionsFlow.Controls.Add(MakeActionButton("Wait 1 Hour", () =>
        {
            _clock.AdvanceSeconds(15);
            _player.AdvanceSimulation(60);
            RefreshUI();
        }));
        actionsFlow.Controls.Add(MakeActionButton("Eat +20", () => { _player.Eat(20); RefreshUI(); }));
        actionsFlow.Controls.Add(MakeActionButton("Drink +20", () => { _player.Drink(20); RefreshUI(); }));
        actionsCard.Controls.Add(actionsFlow);
        _activitiesFlow.Controls.Add(actionsCard);
        TrackWidth(_activitiesFlow, actionsCard);

        RebuildActivityRows();
    }

    private static Button MakeActionButton(string text, Action onClick)
    {
        var btn = new Button { Text = text, AutoSize = true, Margin = new Padding(0, 8, 10, 0) };
        UiTheme.ApplySecondaryButtonStyle(btn);
        btn.Click += (s, e) => onClick();
        return btn;
    }

    private void RebuildActivityRows()
    {
        _activitiesFlow.SuspendLayout();
        foreach (var row in _activityRowControls)
        {
            _activitiesFlow.Controls.Remove(row);
        }
        _activityRowControls.Clear();

        foreach (var def in ActivityDefs)
        {
            var row = BuildActivityRow(def);
            _activityRowControls.Add(row);
            _activitiesFlow.Controls.Add(row);
            TrackWidth(_activitiesFlow, row);
        }

        _activitiesFlow.ResumeLayout();
    }

    private Control BuildActivityRow((string Name, string Description, string Key) def)
    {
        var row = new UiTheme.BorderedPanel { Height = 78, Margin = new Padding(0, 0, 0, 8), Padding = new Padding(14, 10, 14, 10) };
        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 3,
            BackColor = UiTheme.SurfaceRaised,
            Margin = new Padding(0)
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 150));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));

        var nameStack = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        nameStack.Controls.Add(new Label { Text = def.Name, Font = UiTheme.FontBodyBold, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0, 0, 0, 1) });
        nameStack.Controls.Add(new Label { Text = def.Description, Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 0, 0, 0) });
        layout.Controls.Add(nameStack, 0, 0);

        var statusLabel = new Label
        {
            Text = "",
            Font = UiTheme.FontSmall,
            ForeColor = UiTheme.TextMuted,
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleRight,
            Margin = new Padding(0)
        };
        layout.Controls.Add(statusLabel, 1, 0);

        var btn = new Button { Text = "Start", Dock = DockStyle.Fill, Margin = new Padding(8, 0, 0, 0) };
        UiTheme.ApplySecondaryButtonStyle(btn);
        btn.Click += (s, e) => HandleActivityButton(def.Key);
        layout.Controls.Add(btn, 2, 0);

        row.Controls.Add(layout);
        row.Tag = (statusLabel, btn, def.Key);
        return row;
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

    private void RefreshActivityRows()
    {
        string key = $"{_player.IsSleeping}|{_player.IsWorking}|{_player.IsStudying}|{_player.IsPlaying}|{_player.IsSpendingFamilyTime}";
        if (key != _lastActivityKey)
        {
            _lastActivityKey = key;
            RebuildActivityRows();
        }

        foreach (var row in _activityRowControls)
        {
            if (row is not UiTheme.BorderedPanel bordered || bordered.Tag is not (Label status, Button btn, string rowKey)) continue;

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
                status.Text = "ACTIVE";
                status.ForeColor = UiTheme.Accent;
                btn.Text = "Stop";
                UiTheme.ApplyDangerButtonStyle(btn);
                bordered.BorderColor = UiTheme.Accent;
            }
            else
            {
                status.Text = rowKey switch
                {
                    "work" => _player.Age < 18 ? "Age 18+" : "Available",
                    "study" => _player.Age < 6 ? "Age 6+" : "Available",
                    "play" => _player.Age < 2 ? "Age 2+" : "Available",
                    _ => "Available"
                };
                status.ForeColor = UiTheme.TextMuted;
                btn.Text = "Start";
                UiTheme.ApplySecondaryButtonStyle(btn);
                bordered.BorderColor = UiTheme.Border;
            }
        }
    }

    private void RefreshCurrentActivityCard()
    {
        string name = CurrentActivityName(_player);
        _lblLifeActivity.Text = name;
        _lblCurrentActivityName.Text = name.ToUpperInvariant();

        if (name == "Idle")
        {
            _lblCurrentActivityDetail.Text = "You are currently idle.";
        }
        else
        {
            _lblCurrentActivityDetail.Text = $"Started on day {_clock.Day}. Time keeps moving.";
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
        var flow = CreateScreenFlow();
        _screenPeople.Controls.Add(flow);

        flow.Controls.Add(new Label { Text = "FAMILY", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(2, 2, 0, 8) });

        flow.Controls.Add(BuildPersonCard("M", _lblMotherName, _lblMotherInfo, _lblMotherCloseness, _barMotherCloseness, flow));
        flow.Controls.Add(BuildPersonCard("F", _lblFatherName, _lblFatherInfo, _lblFatherCloseness, _barFatherCloseness, flow));

        var friendsCard = new UiTheme.BorderedPanel { Height = 84, Margin = new Padding(0, 6, 0, 10), Padding = new Padding(18, 12, 18, 10) };
        var friendsFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        friendsFlow.Controls.Add(new Label { Text = "FRIENDS", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 0, 0, 4) });
        friendsFlow.Controls.Add(new Label { Text = "You haven't made any friends yet.", Font = UiTheme.FontBody, ForeColor = UiTheme.TextMuted, AutoSize = true });
        friendsCard.Controls.Add(friendsFlow);
        flow.Controls.Add(friendsCard);
        TrackWidth(flow, friendsCard);
    }

    private Control BuildPersonCard(string initial, Label nameLabel, Label infoLabel, Label closenessLabel, GameProgressBar bar, FlowLayoutPanel widthSource)
    {
        var card = new UiTheme.BorderedPanel { Height = 128, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(16, 12, 16, 12) };
        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            BackColor = UiTheme.SurfaceRaised,
            Margin = new Padding(0)
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 56));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

        var avatar = new UiTheme.BorderedPanel { Width = 48, Height = 48, Margin = new Padding(0, 4, 0, 0), BackColor = UiTheme.Surface, Padding = new Padding(0) };
        avatar.BorderColor = UiTheme.Accent;
        var avatarLabel = new Label
        {
            Text = initial,
            Font = UiTheme.FontHeading,
            ForeColor = UiTheme.Accent,
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleCenter,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };
        avatar.Controls.Add(avatarLabel);
        layout.Controls.Add(avatar, 0, 0);

        var infoFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(8, 0, 0, 0) };
        nameLabel.Text = "";
        nameLabel.Font = UiTheme.FontBodyBold;
        nameLabel.ForeColor = UiTheme.TextPrimary;
        nameLabel.AutoSize = true;
        nameLabel.Margin = new Padding(0, 0, 0, 1);
        infoLabel.Text = "";
        infoLabel.Font = UiTheme.FontSmall;
        infoLabel.ForeColor = UiTheme.TextSecondary;
        infoLabel.AutoSize = true;
        infoLabel.Margin = new Padding(0, 0, 0, 6);
        closenessLabel.Text = "Closeness";
        closenessLabel.Font = UiTheme.FontSmall;
        closenessLabel.ForeColor = UiTheme.TextMuted;
        closenessLabel.AutoSize = true;
        closenessLabel.Margin = new Padding(0, 0, 0, 2);
        bar.Height = 10;
        bar.Width = 260;
        bar.Margin = new Padding(0, 0, 0, 0);
        infoFlow.Controls.Add(nameLabel);
        infoFlow.Controls.Add(infoLabel);
        infoFlow.Controls.Add(closenessLabel);
        infoFlow.Controls.Add(bar);
        TrackWidth(infoFlow, bar);
        layout.Controls.Add(infoFlow, 1, 0);

        card.Controls.Add(layout);
        return card;
    }

    private void RefreshPeopleScreen()
    {
        _lblMotherName.Text = _player.Family.Mother.Name;
        _lblMotherInfo.Text = $"Mother · Age {_player.Family.Mother.GetAge(_clock)}";
        _lblMotherCloseness.Text = $"Closeness  {_player.Relationships.MotherRelationship.Closeness:F1}";
        _barMotherCloseness.Configure(0, 100);
        _barMotherCloseness.Value = _player.Relationships.MotherRelationship.Closeness;

        _lblFatherName.Text = _player.Family.Father.Name;
        _lblFatherInfo.Text = $"Father · Age {_player.Family.Father.GetAge(_clock)}";
        _lblFatherCloseness.Text = $"Closeness  {_player.Relationships.FatherRelationship.Closeness:F1}";
        _barFatherCloseness.Configure(0, 100);
        _barFatherCloseness.Value = _player.Relationships.FatherRelationship.Closeness;
    }

    // =====================================================================
    // MORE + SUBSCREENS
    // =====================================================================

    private void BuildMoreScreen()
    {
        var flow = CreateScreenFlow();
        _screenMore.Controls.Add(flow);

        flow.Controls.Add(new Label { Text = "MORE", Font = UiTheme.FontTitle, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(2, 4, 0, 12) });

        void AddMenu(string label, string targetKey)
        {
            var btn = new Button { Text = label, Margin = new Padding(0, 0, 0, 8), Height = 52 };
            UiTheme.ApplySecondaryButtonStyle(btn);
            btn.Click += (s, e) => ShowScreen(targetKey);
            flow.Controls.Add(btn);
            TrackWidth(flow, btn);
        }

        AddMenu("CHARACTER", "character");
        AddMenu("EDUCATION", "education");
        AddMenu("SAVE / LOAD", "saveload");
        AddMenu("SETTINGS", "settings");
    }

    private static Button BuildBackButton(FlowLayoutPanel flow)
    {
        var btn = new Button { Text = "Back", AutoSize = true, Margin = new Padding(0, 0, 0, 10) };
        UiTheme.ApplySecondaryButtonStyle(btn);
        btn.Click += (s, e) => { /* target set by caller */ };
        return btn;
    }

    private void BuildCharacterScreen()
    {
        var flow = CreateScreenFlow();
        _screenCharacter.Controls.Add(flow);

        var back = new Button { Text = "Back", AutoSize = true, Margin = new Padding(0, 0, 0, 10) };
        UiTheme.ApplySecondaryButtonStyle(back);
        back.Click += (s, e) => ShowScreen("more");
        flow.Controls.Add(back);

        var identityCard = new UiTheme.BorderedPanel { Height = 88, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(18, 12, 18, 10) };
        var identityFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _lblCharAgeStage = new Label { Text = "Age 0 · Infant", Font = UiTheme.FontHeading, ForeColor = UiTheme.TextPrimary, AutoSize = true };
        identityFlow.Controls.Add(_lblCharAgeStage);
        identityCard.Controls.Add(identityFlow);
        flow.Controls.Add(identityCard);
        TrackWidth(flow, identityCard);

        flow.Controls.Add(new Label { Text = "ATTRIBUTES", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(2, 6, 0, 6) });
        _lblIntel = new Label();
        _lblFitness = new Label();
        _lblSocial = new Label();
        _lblDiscipline = new Label();
        _lblCreativity = new Label();
        flow.Controls.Add(BuildStatRow("Intelligence", _lblIntel, null, flow));
        flow.Controls.Add(BuildStatRow("Fitness", _lblFitness, null, flow));
        flow.Controls.Add(BuildStatRow("Social", _lblSocial, null, flow));
        flow.Controls.Add(BuildStatRow("Discipline", _lblDiscipline, null, flow));
        flow.Controls.Add(BuildStatRow("Creativity", _lblCreativity, null, flow));

        flow.Controls.Add(new Label { Text = "TRAITS", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(2, 10, 0, 6) });
        _lblConfidence = new Label();
        _lblCuriosity = new Label();
        _lblPatience = new Label();
        _lblAmbition = new Label();
        _lblEmpathy = new Label();
        flow.Controls.Add(BuildStatRow("Confidence", _lblConfidence, null, flow));
        flow.Controls.Add(BuildStatRow("Curiosity", _lblCuriosity, null, flow));
        flow.Controls.Add(BuildStatRow("Patience", _lblPatience, null, flow));
        flow.Controls.Add(BuildStatRow("Ambition", _lblAmbition, null, flow));
        flow.Controls.Add(BuildStatRow("Empathy", _lblEmpathy, null, flow));

        flow.Controls.Add(new Label { Text = "SKILLS", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(2, 10, 0, 6) });
        var skillCard = new UiTheme.BorderedPanel { Height = 108, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(18, 12, 18, 10) };
        var skillFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        _lblAcademics = new Label { Text = "Academics — Level 0", Font = UiTheme.FontBodyBold, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0, 0, 0, 6) };
        _barAcademics.Height = 10;
        _barAcademics.Width = 380;
        skillFlow.Controls.Add(_lblAcademics);
        skillFlow.Controls.Add(_barAcademics);
        TrackWidth(skillFlow, _barAcademics);
        skillCard.Controls.Add(skillFlow);
        flow.Controls.Add(skillCard);
        TrackWidth(flow, skillCard);
    }

    private Control BuildStatRow(string name, Label valueLabel, GameProgressBar? bar, FlowLayoutPanel widthSource)
    {
        var row = new TableLayoutPanel
        {
            ColumnCount = 3,
            AutoSize = true,
            BackColor = UiTheme.Background,
            Margin = new Padding(0, 1, 0, 1)
        };
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 120));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 70));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

        row.Controls.Add(new Label { Text = name, Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(2, 6, 0, 0) }, 0, 0);

        valueLabel.Text = "0";
        valueLabel.Font = UiTheme.FontBodyBold;
        valueLabel.ForeColor = UiTheme.TextPrimary;
        valueLabel.AutoSize = true;
        valueLabel.Margin = new Padding(0, 6, 0, 0);
        row.Controls.Add(valueLabel, 1, 0);

        if (bar != null)
        {
            bar.Height = 10;
            bar.Margin = new Padding(0, 9, 0, 0);
            row.Controls.Add(bar, 2, 0);
        }
        else
        {
            var inlineBar = new GameProgressBar { Height = 10, Margin = new Padding(8, 9, 0, 0) };
            inlineBar.Tag = name;
            row.Controls.Add(inlineBar, 2, 0);
            _charBars[name] = inlineBar;
        }

        void Apply() => row.Width = Math.Max(260, widthSource.ClientSize.Width - row.Margin.Horizontal);
        widthSource.Resize += (s, e) => Apply();
        return row;
    }

    private readonly Dictionary<string, GameProgressBar> _charBars = new();

    private void RefreshCharacterScreen()
    {
        _lblCharAgeStage.Text = $"Age {_player.Age} · {_player.LifeStage}";

        _lblIntel.Text = FormatStat(_player.Attributes.Intelligence);
        _lblFitness.Text = FormatStat(_player.Attributes.Fitness);
        _lblSocial.Text = FormatStat(_player.Attributes.Social);
        _lblDiscipline.Text = FormatStat(_player.Attributes.Discipline);
        _lblCreativity.Text = FormatStat(_player.Attributes.Creativity);

        _lblConfidence.Text = FormatStat(_player.Traits.Confidence);
        _lblCuriosity.Text = FormatStat(_player.Traits.Curiosity);
        _lblPatience.Text = FormatStat(_player.Traits.Patience);
        _lblAmbition.Text = FormatStat(_player.Traits.Ambition);
        _lblEmpathy.Text = FormatStat(_player.Traits.Empathy);

        foreach (var pair in _charBars)
        {
            pair.Value.Configure(0, 100);
        }
        if (_charBars.TryGetValue("Intelligence", out var b1)) b1.Value = _player.Attributes.Intelligence;
        if (_charBars.TryGetValue("Fitness", out var b2)) b2.Value = _player.Attributes.Fitness;
        if (_charBars.TryGetValue("Social", out var b3)) b3.Value = _player.Attributes.Social;
        if (_charBars.TryGetValue("Discipline", out var b4)) b4.Value = _player.Attributes.Discipline;
        if (_charBars.TryGetValue("Creativity", out var b5)) b5.Value = _player.Attributes.Creativity;
        if (_charBars.TryGetValue("Confidence", out var b6)) b6.Value = _player.Traits.Confidence;
        if (_charBars.TryGetValue("Curiosity", out var b7)) b7.Value = _player.Traits.Curiosity;
        if (_charBars.TryGetValue("Patience", out var b8)) b8.Value = _player.Traits.Patience;
        if (_charBars.TryGetValue("Ambition", out var b9)) b9.Value = _player.Traits.Ambition;
        if (_charBars.TryGetValue("Empathy", out var b10)) b10.Value = _player.Traits.Empathy;

        _lblAcademics.Text = $"Academics — Level {_player.Skills.Academics.Level}";
        _barAcademics.Configure(0, SkillProgress.MaxExperience);
        _barAcademics.Value = _player.Skills.Academics.Experience;
    }

    private static string FormatStat(double value) => value.ToString("F1");

    private void BuildEducationScreen()
    {
        var flow = CreateScreenFlow();
        _screenEducation.Controls.Add(flow);

        var back = new Button { Text = "Back", AutoSize = true, Margin = new Padding(0, 0, 0, 10) };
        UiTheme.ApplySecondaryButtonStyle(back);
        back.Click += (s, e) => ShowScreen("more");
        flow.Controls.Add(back);

        var card = new UiTheme.BorderedPanel { Height = 300, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(18, 14, 18, 12) };
        var cardFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };

        _lblEduTitle = new Label { Text = "PRIMARY SCHOOL", Font = UiTheme.FontHeading, ForeColor = UiTheme.TextPrimary, AutoSize = true, Margin = new Padding(0, 0, 0, 6) };
        _lblEduGrade = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true };
        _lblEduProgress = new Label { Text = "Education Progress", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 8, 0, 2) };
        _barEduProgress = new GameProgressBar { Height = 10, Width = 380 };
        _lblEduYear = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 6, 0, 0) };
        _lblEduAcademics = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 2, 0, 0) };
        _lblEduStatus = new Label { Text = "", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 2, 0, 0) };

        _btnEnroll = new Button { Text = "Enroll in Primary School", AutoSize = true, Margin = new Padding(0, 10, 0, 0) };
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

        _lblEduFeedback = new Label { Text = "", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 6, 0, 0) };

        cardFlow.Controls.Add(_lblEduTitle);
        cardFlow.Controls.Add(_lblEduGrade);
        cardFlow.Controls.Add(_lblEduProgress);
        cardFlow.Controls.Add(_barEduProgress);
        cardFlow.Controls.Add(_lblEduYear);
        cardFlow.Controls.Add(_lblEduAcademics);
        cardFlow.Controls.Add(_lblEduStatus);
        cardFlow.Controls.Add(_btnEnroll);
        cardFlow.Controls.Add(_lblEduFeedback);
        TrackWidth(cardFlow, _barEduProgress);
        card.Controls.Add(cardFlow);
        flow.Controls.Add(card);
        TrackWidth(flow, card);
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
                _lblEduProgress.Text = "Education Progress";
                _barEduProgress.Visible = true;
                _barEduProgress.Configure(0, 100);
                _barEduProgress.Value = _player.Education.EducationProgress;
                _lblEduProgress.Text = $"Education Progress   {_player.Education.EducationProgress} / 100";
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
        var flow = CreateScreenFlow();
        _screenSaveLoad.Controls.Add(flow);

        var back = new Button { Text = "Back", AutoSize = true, Margin = new Padding(0, 0, 0, 10) };
        UiTheme.ApplySecondaryButtonStyle(back);
        back.Click += (s, e) => ShowScreen("more");
        flow.Controls.Add(back);

        var card = new UiTheme.BorderedPanel { Height = 168, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(18, 14, 18, 12) };
        var cardFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        cardFlow.Controls.Add(new Label { Text = "SAVE / LOAD", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 0, 0, 8) });

        var saveBtn = new Button { Text = "SAVE GAME", AutoSize = true, Margin = new Padding(0, 0, 10, 0) };
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
        _lblSaveFeedback = new Label { Text = "", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 10, 0, 0) };
        cardFlow.Controls.Add(_lblSaveFeedback);
        card.Controls.Add(cardFlow);
        flow.Controls.Add(card);
        TrackWidth(flow, card);
    }

    private void BuildSettingsScreen()
    {
        var flow = CreateScreenFlow();
        _screenSettings.Controls.Add(flow);

        var back = new Button { Text = "Back", AutoSize = true, Margin = new Padding(0, 0, 0, 10) };
        UiTheme.ApplySecondaryButtonStyle(back);
        back.Click += (s, e) => ShowScreen("more");
        flow.Controls.Add(back);

        var card = new UiTheme.BorderedPanel { Height = 128, Margin = new Padding(0, 0, 0, 10), Padding = new Padding(18, 14, 18, 12) };
        var cardFlow = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = UiTheme.SurfaceRaised, Margin = new Padding(0) };
        cardFlow.Controls.Add(new Label { Text = "INTERFACE", Font = UiTheme.FontSection, ForeColor = UiTheme.TextMuted, AutoSize = true, Margin = new Padding(0, 0, 0, 6) });
        cardFlow.Controls.Add(new Label { Text = "More settings will be available later.", Font = UiTheme.FontBody, ForeColor = UiTheme.TextSecondary, AutoSize = true });
        card.Controls.Add(cardFlow);
        flow.Controls.Add(card);
        TrackWidth(flow, card);
    }

    // =====================================================================
    // GOD MODE OVERLAY (F2)
    // =====================================================================

    private void BuildGodModeOverlay()
    {
        _godModePanel = new Panel
        {
            Dock = DockStyle.Right,
            Width = 250,
            BackColor = UiTheme.Surface,
            Visible = false,
            Padding = new Padding(14)
        };

        var flow = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoScroll = true,
            BackColor = UiTheme.Surface,
            Margin = new Padding(0)
        };

        flow.Controls.Add(new Label { Text = "DEVELOPER — GOD MODE", Font = UiTheme.FontSection, ForeColor = UiTheme.Warning, AutoSize = true, Margin = new Padding(0, 0, 0, 8) });
        flow.Controls.Add(new Label { Text = "Enabled (F2 to hide)", Font = UiTheme.FontSmall, ForeColor = UiTheme.TextSecondary, AutoSize = true, Margin = new Padding(0, 0, 0, 8) });

        void AddGodButton(string text, Action action)
        {
            var btn = new Button { Text = text, Margin = new Padding(0, 0, 0, 6), Width = 214 };
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

        _godModePanel.Controls.Add(flow);
        Controls.Add(_godModePanel);
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
            _btnRunToggle.ForeColor = UiTheme.TextPrimary;
        }
    }

    private void RefreshUI()
    {
        RefreshTopBar();

        _lblLifeAge.Text = $"Age {_player.Age}";
        _lblLifeStage.Text = _player.LifeStage.ToString();
        _lblLifeMoney.Text = $"{_player.Money:N0}";

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
        RefreshCurrentActivityCard();
        RefreshActivityRows();
        RefreshActivityProgressCard();
        RefreshPeopleScreen();
        RefreshCharacterScreen();
        RefreshEducationScreen();
    }
}
