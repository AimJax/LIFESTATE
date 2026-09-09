using System;
using System.Windows.Forms;
using Lifestate;

namespace Lifestate;

public class MainForm : Form
{
    private readonly PlayerState _player;
    private readonly GameClock _clock;
    private readonly System.Windows.Forms.Timer _timer;

    private Label _lblAge;
    private Label _lblLifeStage;
    private Label _lblStatus;
    private Label _lblEnergy;
    private Label _lblHunger;
    private Label _lblThirst;

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
        Size = new System.Drawing.Size(300, 420);

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

        panel.Controls.Add(_lblAge);
        panel.Controls.Add(_lblLifeStage);
        panel.Controls.Add(_lblStatus);
        panel.Controls.Add(_lblEnergy);
        panel.Controls.Add(_lblHunger);
        panel.Controls.Add(_lblThirst);

        var btnStart = new Button { Text = "Start Time" };
        btnStart.Click += (s, e) => _timer.Start();
        panel.Controls.Add(btnStart);

        var btnPause = new Button { Text = "Pause Time" };
        btnPause.Click += (s, e) => _timer.Stop();
        panel.Controls.Add(btnPause);

        var btnWait = new Button { Text = "Wait 1 Hour" };
        btnWait.Click += (s, e) => {
            _clock.AdvanceSeconds(15); // 15 seconds * 4 = 60 minutes
            _player.AdvanceSimulation(60);
            RefreshUI();
        };
        panel.Controls.Add(btnWait);

        var btnSleep = new Button { Text = "Sleep" };
        btnSleep.Click += (s, e) => {
            _player.StartSleeping();
            RefreshUI();
        };
        panel.Controls.Add(btnSleep);

        var btnWake = new Button { Text = "Wake Up" };
        btnWake.Click += (s, e) => {
            _player.StopSleeping();
            RefreshUI();
        };
        panel.Controls.Add(btnWake);

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
        _lblStatus.Text = $"Day: {_clock.Day}, Time: {_clock.Hour:00}:{_clock.Minute:00}, State: {(_player.IsSleeping ? "Sleeping" : "Awake")}";
        _lblEnergy.Text = $"Energy: {_player.Energy}";
        _lblHunger.Text = $"Hunger: {_player.Hunger}";
        _lblThirst.Text = $"Thirst: {_player.Thirst}";
    }
}
