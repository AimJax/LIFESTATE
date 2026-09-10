using System;
using System.Windows.Forms;
using Lifestate;

namespace Lifestate;

public class MainForm : Form
{
    private readonly PlayerState _player;
    private readonly GameClock _clock;
    private readonly GodMode _godMode;
    private readonly System.Windows.Forms.Timer _timer;

    private Label _lblAge = new();
    private Label _lblLifeStage = new();
    private Label _lblStatus = new();
    private Label _lblEnergy = new();
    private Label _lblHunger = new();
    private Label _lblThirst = new();
    private Label _lblMoney = new();
    private Label _lblStudyXP = new();
    private Label _lblIntelligence = new();
    private Label _lblFitness = new();
    private Label _lblSocial = new();
    private Label _lblDiscipline = new();
    private Label _lblCreativity = new();
    private Label _lblFeedback = new();

    private FlowLayoutPanel _debugPanel = new();

    public MainForm(PlayerState player, GameClock clock)
    {
        _player = player;
        _clock = clock;
        _godMode = new GodMode(clock, player);
        _timer = new System.Windows.Forms.Timer { Interval = 1000 };
        _timer.Tick += (s, e) => {
            _clock.AdvanceSeconds(1);
            _player.AdvanceSimulation(GameClock.MinutesPerRealSecond);
            RefreshUI();
        };

        Text = "LIFESTATE Prototype";
        Size = new System.Drawing.Size(300, 500);

        InitializeComponents();
        RefreshUI();
    }

    private void InitializeComponents()
    {
        var panel = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown };

        _lblAge = new Label { AutoSize = true };
        _lblLifeStage = new Label { AutoSize = true };
        _lblStatus = new Label { AutoSize = true };
        _lblEnergy = new Label { AutoSize = true };
        _lblHunger = new Label { AutoSize = true };
        _lblThirst = new Label { AutoSize = true };
        _lblMoney = new Label { AutoSize = true };
        _lblStudyXP = new Label { AutoSize = true };
        _lblIntelligence = new Label { AutoSize = true };
        _lblFitness = new Label { AutoSize = true };
        _lblSocial = new Label { AutoSize = true };
        _lblDiscipline = new Label { AutoSize = true };
        _lblCreativity = new Label { AutoSize = true };
        _lblFeedback = new Label { AutoSize = true, ForeColor = System.Drawing.Color.Red };

        panel.Controls.Add(_lblAge);
        panel.Controls.Add(_lblLifeStage);
        panel.Controls.Add(_lblStatus);
        panel.Controls.Add(_lblEnergy);
        panel.Controls.Add(_lblHunger);
        panel.Controls.Add(_lblThirst);
        panel.Controls.Add(_lblMoney);
        panel.Controls.Add(_lblStudyXP);
        panel.Controls.Add(_lblIntelligence);
        panel.Controls.Add(_lblFitness);
        panel.Controls.Add(_lblSocial);
        panel.Controls.Add(_lblDiscipline);
        panel.Controls.Add(_lblCreativity);
        panel.Controls.Add(_lblFeedback);

        var btnStart = new Button { Text = "Start Time" };
        btnStart.Click += (s, e) => { _timer.Start(); _lblFeedback.Text = ""; };
        panel.Controls.Add(btnStart);

        var btnPause = new Button { Text = "Pause Time" };
        btnPause.Click += (s, e) => _timer.Stop();
        panel.Controls.Add(btnPause);

        var btnWait = new Button { Text = "Wait 1 Hour" };
        btnWait.Click += (s, e) => {
            _clock.AdvanceSeconds(15);
            _player.AdvanceSimulation(60);
            RefreshUI();
        };
        panel.Controls.Add(btnWait);

        var btnSleep = new Button { Text = "Sleep" };
        btnSleep.Click += (s, e) => {
            _player.StartSleeping();
            _lblFeedback.Text = "";
            RefreshUI();
        };
        panel.Controls.Add(btnSleep);

        var btnWake = new Button { Text = "Wake Up" };
        btnWake.Click += (s, e) => {
            _player.StopSleeping();
            RefreshUI();
        };
        panel.Controls.Add(btnWake);

        var btnWork = new Button { Text = "Work" };
        btnWork.Click += (s, e) => {
            if (_player.Age < 18)
            {
                _lblFeedback.Text = "Cannot work before age 18.";
            }
            else
            {
                _player.StartWorking();
                _lblFeedback.Text = "";
            }
            RefreshUI();
        };
        panel.Controls.Add(btnWork);

        var btnStopWork = new Button { Text = "Stop Work" };
        btnStopWork.Click += (s, e) => {
            _player.StopWorking();
            RefreshUI();
        };
        panel.Controls.Add(btnStopWork);

        var btnEat = new Button { Text = "Eat +20" };
        btnEat.Click += (s, e) => {
            _player.Eat(20);
            RefreshUI();
        };
        panel.Controls.Add(btnEat);

        var btnDrink = new Button { Text = "Drink +20" };
        btnDrink.Click += (s, e) => {
            _player.Drink(20);
            RefreshUI();
        };
        panel.Controls.Add(btnDrink);

        var btnStudy = new Button { Text = "Study" };
        btnStudy.Click += (s, e) => {
            if (_player.Age < 6)
            {
                _lblFeedback.Text = "Cannot study before age 6.";
            }
            else if (_player.IsSleeping)
            {
                _lblFeedback.Text = "Cannot study while sleeping.";
            }
            else if (_player.IsWorking)
            {
                _lblFeedback.Text = "Cannot study while working.";
            }
            else
            {
                _player.StartStudying();
                _lblFeedback.Text = "";
            }
            RefreshUI();
        };
        panel.Controls.Add(btnStudy);

        var btnStopStudy = new Button { Text = "Stop Study" };
        btnStopStudy.Click += (s, e) => {
            _player.StopStudying();
            RefreshUI();
        };
        panel.Controls.Add(btnStopStudy);

        var btnSave = new Button { Text = "Save" };
        btnSave.Click += (s, e) => {
            SaveManager.Save(_clock, _player);
            _lblFeedback.Text = "Saved.";
        };
        panel.Controls.Add(btnSave);

        var btnLoad = new Button { Text = "Load" };
        btnLoad.Click += (s, e) => {
            if (SaveManager.Load(_clock, _player))
            {
                RefreshUI();
                _lblFeedback.Text = "Loaded.";
            }
            else
            {
                _lblFeedback.Text = "Load failed.";
            }
        };
        panel.Controls.Add(btnLoad);

        var btnToggleGodMode = new Button { Text = "GOD MODE: OFF" };
        _debugPanel = new FlowLayoutPanel { Visible = false, FlowDirection = FlowDirection.TopDown, AutoSize = true };
        btnToggleGodMode.Click += (s, e) => {
            _godMode.SetEnabled(!_godMode.IsEnabled);
            btnToggleGodMode.Text = _godMode.IsEnabled ? "GOD MODE: ON" : "GOD MODE: OFF";
            _debugPanel.Visible = _godMode.IsEnabled;
        };
        panel.Controls.Add(btnToggleGodMode);

        var btnDay = new Button { Text = "+1 Day" };
        btnDay.Click += (s, e) => { _godMode.AdvanceDays(1); RefreshUI(); };
        _debugPanel.Controls.Add(btnDay);

        var btnYear = new Button { Text = "+1 Year" };
        btnYear.Click += (s, e) => { _godMode.AdvanceDays(365); RefreshUI(); };
        _debugPanel.Controls.Add(btnYear);

        var btn10Years = new Button { Text = "+10 Years" };
        btn10Years.Click += (s, e) => { _godMode.AdvanceDays(3650); RefreshUI(); };
        _debugPanel.Controls.Add(btn10Years);

        var btnMoney = new Button { Text = "+100 Money" };
        btnMoney.Click += (s, e) => { _godMode.AddMoney(100); RefreshUI(); };
        _debugPanel.Controls.Add(btnMoney);

        var btnNeeds = new Button { Text = "Restore Needs" };
        btnNeeds.Click += (s, e) => { _godMode.RestoreNeeds(); RefreshUI(); };
        _debugPanel.Controls.Add(btnNeeds);

        var btnMaxAttrs = new Button { Text = "Max Attributes" };
        btnMaxAttrs.Click += (s, e) => { _godMode.MaxAttributes(); RefreshUI(); };
        _debugPanel.Controls.Add(btnMaxAttrs);

        panel.Controls.Add(_debugPanel);

        Controls.Add(panel);
    }

    private void RefreshUI()
    {
        _lblAge.Text = $"Age: {_player.Age}";
        _lblLifeStage.Text = $"Life Stage: {_player.LifeStage}";
        string state = _player.IsSleeping ? "Sleeping" : (_player.IsWorking ? "Working" : (_player.IsStudying ? "Studying" : "Awake"));
        _lblStatus.Text = $"Day: {_clock.Day}, Time: {_clock.Hour:00}:{_clock.Minute:00}, State: {state}";
        _lblEnergy.Text = $"Energy: {_player.Energy}";
        _lblHunger.Text = $"Hunger: {_player.Hunger}";
        _lblThirst.Text = $"Thirst: {_player.Thirst}";
        _lblMoney.Text = $"Money: {_player.Money}";
        _lblStudyXP.Text = $"Study XP: {_player.StudyXP}";
        _lblIntelligence.Text = $"Intelligence: {_player.Attributes.Intelligence:F2}";
        _lblFitness.Text = $"Fitness: {_player.Attributes.Fitness:F2}";
        _lblSocial.Text = $"Social: {_player.Attributes.Social:F2}";
        _lblDiscipline.Text = $"Discipline: {_player.Attributes.Discipline:F2}";
        _lblCreativity.Text = $"Creativity: {_player.Attributes.Creativity:F2}";
    }
}
