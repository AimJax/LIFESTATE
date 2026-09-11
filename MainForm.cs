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
    private Label _lblAcademics = new();
    private Label _lblEducation = new();
    private Label _lblConfidence = new();
    private Label _lblCuriosity = new();
    private Label _lblPatience = new();
    private Label _lblAmbition = new();
    private Label _lblEmpathy = new();
    private Label _lblMother = new();
    private Label _lblFather = new();
    private Label _lblEvent = new();
    private Label _lblEventHistory = new();
    private FlowLayoutPanel _eventChoicesPanel = new();
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
        Size = new System.Drawing.Size(350, 600);

        InitializeComponents();
        RefreshUI();
    }

    private void InitializeComponents()
    {
        var panel = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, AutoScroll = true };

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
        _lblAcademics = new Label { AutoSize = true };
        _lblEducation = new Label { AutoSize = true };
        _lblConfidence = new Label { AutoSize = true };
        _lblCuriosity = new Label { AutoSize = true };
        _lblPatience = new Label { AutoSize = true };
        _lblAmbition = new Label { AutoSize = true };
        _lblEmpathy = new Label { AutoSize = true };
        _lblMother = new Label { AutoSize = true };
        _lblFather = new Label { AutoSize = true };
        _lblEvent = new Label { AutoSize = true, MaximumSize = new System.Drawing.Size(320, 0) };
        _eventChoicesPanel = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false };
        _lblEventHistory = new Label { AutoSize = true, MaximumSize = new System.Drawing.Size(320, 0) };
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
        panel.Controls.Add(_lblAcademics);
        panel.Controls.Add(_lblEducation);
        panel.Controls.Add(_lblConfidence);
        panel.Controls.Add(_lblCuriosity);
        panel.Controls.Add(_lblPatience);
        panel.Controls.Add(_lblAmbition);
        panel.Controls.Add(_lblEmpathy);
        panel.Controls.Add(_lblMother);
        panel.Controls.Add(_lblFather);
        panel.Controls.Add(_lblEvent);
        panel.Controls.Add(_eventChoicesPanel);
        panel.Controls.Add(_lblEventHistory);
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
        btnSleep.Click += (s, e) => { _player.StartSleeping(); _lblFeedback.Text = ""; RefreshUI(); };
        panel.Controls.Add(btnSleep);

        var btnWake = new Button { Text = "Wake Up" };
        btnWake.Click += (s, e) => { _player.StopSleeping(); RefreshUI(); };
        panel.Controls.Add(btnWake);

        var btnWork = new Button { Text = "Work" };
        btnWork.Click += (s, e) => {
            if (_player.Age < 18) _lblFeedback.Text = "Cannot work before age 18.";
            else { _player.StartWorking(); _lblFeedback.Text = ""; }
            RefreshUI();
        };
        panel.Controls.Add(btnWork);

        var btnStopWork = new Button { Text = "Stop Work" };
        btnStopWork.Click += (s, e) => { _player.StopWorking(); RefreshUI(); };
        panel.Controls.Add(btnStopWork);

        var btnEat = new Button { Text = "Eat +20" };
        btnEat.Click += (s, e) => { _player.Eat(20); RefreshUI(); };
        panel.Controls.Add(btnEat);

        var btnDrink = new Button { Text = "Drink +20" };
        btnDrink.Click += (s, e) => { _player.Drink(20); RefreshUI(); };
        panel.Controls.Add(btnDrink);

        var btnPlay = new Button { Text = "Play" };
        btnPlay.Click += (s, e) => {
            if (_player.Age < 2)
                _lblFeedback.Text = "Cannot play before age 2.";
            else if (_player.IsSleeping)
                _lblFeedback.Text = "Cannot play while sleeping.";
            else if (_player.IsWorking)
                _lblFeedback.Text = "Cannot play while working.";
            else if (_player.IsStudying)
                _lblFeedback.Text = "Cannot play while studying.";
            else if (_player.IsPlaying)
                _lblFeedback.Text = "Already playing.";
            else if (!_player.StartPlaying())
                _lblFeedback.Text = "Cannot play.";
            else
                _lblFeedback.Text = "";
            RefreshUI();
        };
        panel.Controls.Add(btnPlay);

        var btnStopPlay = new Button { Text = "Stop Play" };
        btnStopPlay.Click += (s, e) => { _player.StopPlaying(); RefreshUI(); };
        panel.Controls.Add(btnStopPlay);

        var btnFamilyTime = new Button { Text = "Spend Time With Family" };
        btnFamilyTime.Click += (s, e) => {
            if (_player.IsSleeping)
                _lblFeedback.Text = "Cannot spend time with family while sleeping.";
            else if (_player.IsWorking)
                _lblFeedback.Text = "Cannot spend time with family while working.";
            else if (_player.IsStudying)
                _lblFeedback.Text = "Cannot spend time with family while studying.";
            else if (_player.IsPlaying)
                _lblFeedback.Text = "Cannot spend time with family while playing.";
            else if (_player.IsSpendingFamilyTime)
                _lblFeedback.Text = "Already spending time with family.";
            else if (!_player.StartFamilyTime())
                _lblFeedback.Text = "Cannot start family time.";
            else
                _lblFeedback.Text = "";
            RefreshUI();
        };
        panel.Controls.Add(btnFamilyTime);

        var btnStopFamilyTime = new Button { Text = "Stop Family Time" };
        btnStopFamilyTime.Click += (s, e) => { _player.StopFamilyTime(); RefreshUI(); };
        panel.Controls.Add(btnStopFamilyTime);

        var btnStudy = new Button { Text = "Study" };
        btnStudy.Click += (s, e) => {
            if (_player.Age < 6) _lblFeedback.Text = "Cannot study before age 6.";
            else if (_player.IsSleeping) _lblFeedback.Text = "Cannot study while sleeping.";
            else if (_player.IsWorking) _lblFeedback.Text = "Cannot study while working.";
            else { _player.StartStudying(); _lblFeedback.Text = ""; }
            RefreshUI();
        };
        panel.Controls.Add(btnStudy);

        var btnStopStudy = new Button { Text = "Stop Study" };
        btnStopStudy.Click += (s, e) => { _player.StopStudying(); RefreshUI(); };
        panel.Controls.Add(btnStopStudy);

        var btnSave = new Button { Text = "Save" };
        btnSave.Click += (s, e) => { SaveManager.Save(_clock, _player); _lblFeedback.Text = "Saved."; };
        panel.Controls.Add(btnSave);

        var btnLoad = new Button { Text = "Load" };
        btnLoad.Click += (s, e) => {
            _lblFeedback.Text = SaveManager.Load(_clock, _player) ? "Loaded." : "Load failed.";
            RefreshUI();
        };
        panel.Controls.Add(btnLoad);

        var btnEnroll = new Button { Text = "Enroll Primary School" };
        btnEnroll.Click += (s, e) => {
            if (_player.Age < 6)
                _lblFeedback.Text = "Must be at least age 6 to enroll.";
            else if (_player.Education.Status == EducationStatus.PrimarySchool)
                _lblFeedback.Text = "Already enrolled in Primary School.";
            else if (_player.Education.Status == EducationStatus.CompletedPrimary)
                _lblFeedback.Text = "Primary School already completed.";
            else if (_player.EnrollPrimarySchool())
                _lblFeedback.Text = "Enrolled.";
            else
                _lblFeedback.Text = "Enrollment failed.";
            RefreshUI();
        };
        panel.Controls.Add(btnEnroll);

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
        var btnMaxSkills = new Button { Text = "Max Skills" };
        btnMaxSkills.Click += (s, e) => { _godMode.MaxSkills(); RefreshUI(); };
        _debugPanel.Controls.Add(btnMaxSkills);
        var btnMaxTraits = new Button { Text = "Max Traits" };
        btnMaxTraits.Click += (s, e) => { _godMode.MaxTraits(); RefreshUI(); };
        _debugPanel.Controls.Add(btnMaxTraits);

        panel.Controls.Add(_debugPanel);
        Controls.Add(panel);
    }

    private void RefreshUI()
    {
        _lblAge.Text = $"Age: {_player.Age}";
        _lblLifeStage.Text = $"Life Stage: {_player.LifeStage}";
        string state = _player.IsSleeping ? "Sleeping" : (_player.IsWorking ? "Working" : (_player.IsStudying ? "Studying" : (_player.IsPlaying ? "Playing" : (_player.IsSpendingFamilyTime ? "Family Time" : "Awake"))));
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
        _lblAcademics.Text = $"Academics: Lv. {_player.Skills.Academics.Level}  XP: {_player.Skills.Academics.Experience}/{SkillProgress.MaxExperience}";

        if (_player.Education.Status == EducationStatus.NotEnrolled)
            _lblEducation.Text = "Education: Not Enrolled";
        else if (_player.Education.Status == EducationStatus.PrimarySchool)
        {
            long elapsed = _clock.Day - _player.Education.SchoolYearStartDay;
            _lblEducation.Text = $"Education: Primary School | Grade: {_player.Education.PrimaryGrade} | Progress: {_player.Education.EducationProgress}/100 | Year: {Math.Min(elapsed, 365)}/365 days";
        }
        else
            _lblEducation.Text = "Education: Primary Completed";

        _lblConfidence.Text = $"Confidence: {_player.Traits.Confidence:F2}";
        _lblCuriosity.Text = $"Curiosity: {_player.Traits.Curiosity:F2}";
        _lblPatience.Text = $"Patience: {_player.Traits.Patience:F2}";
        _lblAmbition.Text = $"Ambition: {_player.Traits.Ambition:F2}";
        _lblEmpathy.Text = $"Empathy: {_player.Traits.Empathy:F2}";

        _lblMother.Text = $"Mother: {_player.Family.Mother.Name} | Age: {_player.Family.Mother.GetAge(_clock)} | Relationship: {_player.Relationships.MotherRelationship.Closeness:F2}";
        _lblFather.Text = $"Father: {_player.Family.Father.Name} | Age: {_player.Family.Father.GetAge(_clock)} | Relationship: {_player.Relationships.FatherRelationship.Closeness:F2}";

        // Event section: pending event + choices, or "no pending event".
        var currentEvent = _player.Events.CurrentEvent;
        if (currentEvent == null)
        {
            _lblEvent.Text = "No pending event.";
        }
        else
        {
            var definition = LifeEventCatalog.GetById(currentEvent.EventId);
            _lblEvent.Text = definition == null
                ? "No pending event."
                : $"Event: {definition.Title}\n{definition.Description}";
        }

        // Rebuild choice buttons from the catalog definition (no outcome logic here).
        _eventChoicesPanel.Controls.Clear();
        if (currentEvent != null)
        {
            var eventDefinition = LifeEventCatalog.GetById(currentEvent.EventId);
            if (eventDefinition != null)
            {
                foreach (var choice in eventDefinition.Choices)
                {
                    var choiceLocal = choice;
                    var btnChoice = new Button { Text = choiceLocal.Text, AutoSize = true };
                    btnChoice.Click += (s, e) => {
                        _player.ResolveEventChoice(choiceLocal.Id);
                        RefreshUI();
                    };
                    _eventChoicesPanel.Controls.Add(btnChoice);
                }
            }
        }

        // Event history: "Title — choice text — Day N" per resolved event.
        if (_player.Events.History.Count == 0)
        {
            _lblEventHistory.Text = "Event History: (none)";
        }
        else
        {
            var lines = new System.Text.StringBuilder("Event History:");
            foreach (var entry in _player.Events.History)
            {
                var def = LifeEventCatalog.GetById(entry.EventId);
                string title = def?.Title ?? entry.EventId;
                string choiceText = def?.Choices.FirstOrDefault(c => c.Id == entry.ChoiceId)?.Text ?? entry.ChoiceId;
                lines.Append($"\n{title} — {choiceText} — Day {entry.ResolvedDay}");
            }
            _lblEventHistory.Text = lines.ToString();
        }
    }
}