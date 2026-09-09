using System;
using System.Windows.Forms;
using Lifestate;

namespace Lifestate;

public class MainForm : Form
{
    private readonly PlayerState _player;
    private readonly GameClock _clock;
    private readonly System.Windows.Forms.Timer _timer;

    private Label _lblAge = new();
    private Label _lblLifeStage = new();
    private Label _lblStatus = new();
    private Label _lblEnergy = new();
    private Label _lblHunger = new();
    private Label _lblThirst = new();
    private Label _lblMoney = new();
    private Label _lblFeedback = new();

    public MainForm(PlayerState player, GameClock clock)
    {
        _player = player;
        _clock = clock;
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
        _lblFeedback = new Label { AutoSize = true, ForeColor = System.Drawing.Color.Red };

        panel.Controls.Add(_lblAge);
        panel.Controls.Add(_lblLifeStage);
        panel.Controls.Add(_lblStatus);
        panel.Controls.Add(_lblEnergy);
        panel.Controls.Add(_lblHunger);
        panel.Controls.Add(_lblThirst);
        panel.Controls.Add(_lblMoney);
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

        Controls.Add(panel);
    }

    private void RefreshUI()
    {
        _lblAge.Text = $"Age: {_player.Age}";
        _lblLifeStage.Text = $"Life Stage: {_player.LifeStage}";
        string state = _player.IsSleeping ? "Sleeping" : (_player.IsWorking ? "Working" : "Awake");
        _lblStatus.Text = $"Day: {_clock.Day}, Time: {_clock.Hour:00}:{_clock.Minute:00}, State: {state}";
        _lblEnergy.Text = $"Energy: {_player.Energy}";
        _lblHunger.Text = $"Hunger: {_player.Hunger}";
        _lblThirst.Text = $"Thirst: {_player.Thirst}";
        _lblMoney.Text = $"Money: {_player.Money}";
    }
}
