namespace Lifestate;

public class PlayerState
{
    private readonly GameClock _clock;

    public PlayerState(GameClock clock)
    {
        _clock = clock;
        Relationships = new PlayerRelationships(Family.Mother.Id, Family.Father.Id);
        Events = new LifeEventSystem(this);
    }

    public int Age => _clock.Day / 365;

    public LifeStage LifeStage => Age switch
    {
        <= 1 => LifeStage.Infant,
        <= 5 => LifeStage.EarlyChildhood,
        <= 12 => LifeStage.Child,
        <= 17 => LifeStage.Teen,
        <= 64 => LifeStage.Adult,
        _ => LifeStage.Elder
    };

    public PlayerAttributes Attributes { get; } = new();
    public PlayerSkills Skills { get; } = new();
    public EducationState Education { get; } = new();
    public PlayerTraits Traits { get; } = new();
    public PlayerFamily Family { get; } = new();
    public PlayerRelationships Relationships { get; }
    public LifeEventSystem Events { get; }
    public long TotalPlayHours { get; private set; } = 0;
    public int Money { get; set; } = 1000;
    public int Energy { get; private set; } = 100;
    public int Hunger { get; private set; } = 100;
    public int Thirst { get; private set; } = 100;
    public int StudyXP { get; private set; } = 0;
    public bool IsSleeping { get; private set; } = false;
    public bool IsWorking { get; private set; } = false;
    public bool IsStudying { get; private set; } = false;
    public bool IsPlaying { get; private set; } = false;
    public bool IsSpendingFamilyTime { get; private set; } = false;

    private int _awakeMinutesAccumulator = 0;
    private int _sleepingMinutesAccumulator = 0;
    private int _hungerMinutesAccumulator = 0;
    private int _thirstMinutesAccumulator = 0;
    private int _workMinutesAccumulator = 0;
    private int _studyMinutesAccumulator = 0;
    private int _playMinutesAccumulator = 0;
    private int _familyTimeMinutesAccumulator = 0;

    public void StartSleeping()
    {
        if (IsWorking || IsStudying || IsPlaying || IsSpendingFamilyTime) return;
        IsSleeping = true;
    }
    public void StopSleeping() => IsSleeping = false;

    public void StartWorking()
    {
        if (Age < 18 || IsSleeping || IsStudying || IsPlaying || IsSpendingFamilyTime) return;
        IsWorking = true;
    }
    public void StopWorking() => IsWorking = false;

    public void StartStudying()
    {
        if (Age < 6 || IsSleeping || IsWorking || IsPlaying || IsSpendingFamilyTime) return;
        IsStudying = true;
    }
    public void StopStudying() => IsStudying = false;

    public bool StartPlaying()
    {
        if (Age < 2 || IsSleeping || IsWorking || IsStudying || IsPlaying || IsSpendingFamilyTime) return false;
        IsPlaying = true;
        return true;
    }
    public void StopPlaying() => IsPlaying = false;

    public bool StartFamilyTime()
    {
        if (IsSleeping || IsWorking || IsStudying || IsPlaying || IsSpendingFamilyTime) return false;
        IsSpendingFamilyTime = true;
        return true;
    }
    public void StopFamilyTime() => IsSpendingFamilyTime = false;

    public bool EnrollPrimarySchool()
    {
        if (Age < 6) return false;
        bool enrolled = Education.TryEnroll(_clock.Day);
        if (enrolled)
        {
            // Enrollment can immediately make events eligible (e.g. First Day of School).
            Events.EvaluateTriggers(_clock.Day);
        }
        return enrolled;
    }

    public void UpdateEnergy(int elapsedMinutes)
    {
        if (IsSleeping)
        {
            _sleepingMinutesAccumulator += elapsedMinutes;
            int hoursSlept = _sleepingMinutesAccumulator / 60;
            if (hoursSlept > 0)
            {
                Energy = Math.Min(100, Energy + (hoursSlept * 5));
                _sleepingMinutesAccumulator %= 60;
            }
        }
        else
        {
            _awakeMinutesAccumulator += elapsedMinutes;
            int hoursAwake = _awakeMinutesAccumulator / 60;
            if (hoursAwake > 0)
            {
                Energy = Math.Max(0, Energy - hoursAwake);
                _awakeMinutesAccumulator %= 60;
            }
        }
    }

    public void UpdateHunger(int elapsedMinutes)
    {
        _hungerMinutesAccumulator += elapsedMinutes;
        int hoursPassed = _hungerMinutesAccumulator / 60;
        if (hoursPassed > 0)
        {
            Hunger = Math.Max(0, Hunger - hoursPassed);
            _hungerMinutesAccumulator %= 60;
        }
    }

    public void Eat(int hungerRestored)
    {
        if (hungerRestored <= 0) return;
        Hunger = Math.Min(100, Hunger + hungerRestored);
    }

    public void AdvanceSimulation(int minutes)
    {
        UpdateEnergy(minutes);
        UpdateHunger(minutes);
        UpdateThirst(minutes);
        UpdateWork(minutes);
        UpdateStudy(minutes);
        UpdatePlay(minutes);
        UpdateFamilyTime(minutes);
        Education.EvaluateProgression(_clock.Day);
        Events.EvaluateTriggers(_clock.Day);
    }

    internal void BulkAdvanceSimulation(long elapsedMinutes, out long moneyEarned, out long xpEarned)
    {
        moneyEarned = 0;
        xpEarned = 0;

        if (elapsedMinutes <= 0) return;

        // Energy
        if (IsSleeping)
        {
            long totalSlept = (long)_sleepingMinutesAccumulator + elapsedMinutes;
            long hoursSlept = totalSlept / 60;
            Energy = (int)Math.Min(100, (long)Energy + (hoursSlept * 5));
            _sleepingMinutesAccumulator = (int)(totalSlept % 60);
        }
        else
        {
            long totalAwake = (long)_awakeMinutesAccumulator + elapsedMinutes;
            long hoursAwake = totalAwake / 60;
            Energy = (int)Math.Max(0, (long)Energy - hoursAwake);
            _awakeMinutesAccumulator = (int)(totalAwake % 60);
        }

        // Hunger
        long totalHunger = (long)_hungerMinutesAccumulator + elapsedMinutes;
        long hoursHunger = totalHunger / 60;
        Hunger = (int)Math.Max(0, (long)Hunger - hoursHunger);
        _hungerMinutesAccumulator = (int)(totalHunger % 60);

        // Thirst
        long totalThirst = (long)_thirstMinutesAccumulator + elapsedMinutes;
        long hoursThirst = totalThirst / 60;
        Thirst = (int)Math.Max(0, (long)Thirst - (hoursThirst * 2));
        _thirstMinutesAccumulator = (int)(totalThirst % 60);

        // Work/Study rewards are linear.
        if (IsWorking)
        {
            long totalWorkMinutes = (long)_workMinutesAccumulator + elapsedMinutes;
            moneyEarned = (totalWorkMinutes / 60) * 10;
            _workMinutesAccumulator = (int)(totalWorkMinutes % 60);
        }

        if (IsStudying)
        {
            long totalStudyMinutes = (long)_studyMinutesAccumulator + elapsedMinutes;
            long hoursStudied = totalStudyMinutes / 60;
            xpEarned = hoursStudied * 10;
            Attributes.AddIntelligence(hoursStudied * 0.05);
            Skills.Academics.AddExperience(hoursStudied * 10);
            if (Education.Status == EducationStatus.PrimarySchool)
            {
                int educationHours = (int)Math.Min(hoursStudied, 100L);
                Education.AddProgress(educationHours);
            }
            Traits.AddCuriosity(hoursStudied * 0.02);
            Traits.AddPatience(hoursStudied * 0.01);
            Traits.AddAmbition(hoursStudied * 0.01);
            _studyMinutesAccumulator = (int)(totalStudyMinutes % 60);
        }

        // Play rewards are linear and O(1). long * double stays finite for any
        // valid elapsedMinutes, and Add/AddMutation clamp at 0..100 anyway.
        if (IsPlaying)
        {
            long totalPlayMinutes = (long)_playMinutesAccumulator + elapsedMinutes;
            long hoursPlayed = totalPlayMinutes / 60;
            Attributes.AddFitness(hoursPlayed * 0.03);
            Attributes.AddCreativity(hoursPlayed * 0.03);
            Traits.AddConfidence(hoursPlayed * 0.02);
            Traits.AddCuriosity(hoursPlayed * 0.01);
            _playMinutesAccumulator = (int)(totalPlayMinutes % 60);
            AddTotalPlayHoursSafely(hoursPlayed);
        }

        // Family Time rewards are linear and O(1).
        if (IsSpendingFamilyTime)
        {
            long totalFamilyMinutes = (long)_familyTimeMinutesAccumulator + elapsedMinutes;
            long hoursSpent = totalFamilyMinutes / 60;
            Relationships.MotherRelationship.AddCloseness(hoursSpent * 0.25);
            Relationships.FatherRelationship.AddCloseness(hoursSpent * 0.25);
            Attributes.AddSocial(hoursSpent * 0.02);
            Traits.AddEmpathy(hoursSpent * 0.02);
            Traits.AddConfidence(hoursSpent * 0.01);
            _familyTimeMinutesAccumulator = (int)(totalFamilyMinutes % 60);
        }

        Education.EvaluateProgression(_clock.Day);
        Events.EvaluateTriggers(_clock.Day);
    }

    internal bool PreflightWorkAndStudy(long elapsedMinutes, out long totalMoney, out long totalXP)
    {
        totalMoney = Money;
        totalXP = StudyXP;

        if (IsWorking)
        {
            long totalWorkMinutes = (long)_workMinutesAccumulator + elapsedMinutes;
            long moneyEarned = (totalWorkMinutes / 60) * 10;
            totalMoney += moneyEarned;
        }

        if (IsStudying)
        {
            long totalStudyMinutes = (long)_studyMinutesAccumulator + elapsedMinutes;
            long xpEarned = (totalStudyMinutes / 60) * 10;
            totalXP += xpEarned;
        }

        return totalMoney <= int.MaxValue && totalXP <= int.MaxValue;
    }

    internal void ApplyRewards(long moneyEarned, long xpEarned)
    {
        Money = (int)(Money + moneyEarned);
        StudyXP = (int)(StudyXP + xpEarned);
    }

    public void UpdateWork(int elapsedMinutes)
    {
        if (!IsWorking) return;

        _workMinutesAccumulator += elapsedMinutes;
        int hoursWorked = _workMinutesAccumulator / 60;
        if (hoursWorked > 0)
        {
            Money += (hoursWorked * 10);
            _workMinutesAccumulator %= 60;
        }
    }

    public void UpdateStudy(int elapsedMinutes)
    {
        if (!IsStudying) return;

        _studyMinutesAccumulator += elapsedMinutes;
        int hoursStudied = _studyMinutesAccumulator / 60;
        if (hoursStudied > 0)
        {
            StudyXP += (hoursStudied * 10);
            Attributes.AddIntelligence(hoursStudied * 0.05);
            Skills.Academics.AddExperience(hoursStudied * 10);
            if (Education.Status == EducationStatus.PrimarySchool)
            {
                Education.AddProgress(hoursStudied);
                Education.EvaluateProgression(_clock.Day);
            }
            Traits.AddCuriosity(hoursStudied * 0.02);
            Traits.AddPatience(hoursStudied * 0.01);
            Traits.AddAmbition(hoursStudied * 0.01);
            _studyMinutesAccumulator %= 60;
        }
    }

    public void UpdateThirst(int elapsedMinutes)
    {
        _thirstMinutesAccumulator += elapsedMinutes;
        int hoursPassed = _thirstMinutesAccumulator / 60;
        if (hoursPassed > 0)
        {
            Thirst = Math.Max(0, Thirst - (hoursPassed * 2));
            _thirstMinutesAccumulator %= 60;
        }
    }

    public void UpdatePlay(int elapsedMinutes)
    {
        if (!IsPlaying) return;

        _playMinutesAccumulator += elapsedMinutes;
        int hoursPlayed = _playMinutesAccumulator / 60;
        if (hoursPlayed > 0)
        {
            Attributes.AddFitness(hoursPlayed * 0.03);
            Attributes.AddCreativity(hoursPlayed * 0.03);
            Traits.AddConfidence(hoursPlayed * 0.02);
            Traits.AddCuriosity(hoursPlayed * 0.01);
            _playMinutesAccumulator %= 60;
            AddTotalPlayHoursSafely(hoursPlayed);
        }
    }

    public void UpdateFamilyTime(int elapsedMinutes)
    {
        if (!IsSpendingFamilyTime) return;

        _familyTimeMinutesAccumulator += elapsedMinutes;
        int hoursSpent = _familyTimeMinutesAccumulator / 60;
        if (hoursSpent > 0)
        {
            Relationships.MotherRelationship.AddCloseness(hoursSpent * 0.25);
            Relationships.FatherRelationship.AddCloseness(hoursSpent * 0.25);
            Attributes.AddSocial(hoursSpent * 0.02);
            Traits.AddEmpathy(hoursSpent * 0.02);
            Traits.AddConfidence(hoursSpent * 0.01);
            _familyTimeMinutesAccumulator %= 60;
        }
    }

    public void Drink(int thirstRestored)
    {
        if (thirstRestored <= 0) return;
        Thirst = Math.Min(100, Thirst + thirstRestored);
    }

    internal void DebugAddMoney(int amount)
    {
        if (amount > 0)
        {
            Money += amount;
        }
    }

    /// <summary>
    /// Controlled safe money mutation used by event outcomes.
    /// Saturates at int.MaxValue (never wraps) and never goes below zero.
    /// </summary>
    public void AddMoneySafely(int amount)
    {
        long result = (long)Money + amount;
        Money = (int)Math.Clamp(result, 0, int.MaxValue);
    }

    /// <summary>Lifetime completed Play hours with safe saturation at long.MaxValue.</summary>
    private void AddTotalPlayHoursSafely(long hours)
    {
        if (hours <= 0) return;
        TotalPlayHours = hours >= long.MaxValue - TotalPlayHours
            ? long.MaxValue
            : TotalPlayHours + hours;
    }

    /// <summary>Controlled internal restore of the lifetime Play hour statistic.</summary>
    internal void RestoreTotalPlayHours(long hours)
    {
        if (hours < 0) return;
        TotalPlayHours = hours;
    }

    /// <summary>Controlled facade for resolving the current pending event.</summary>
    public bool ResolveEventChoice(string choiceId)
    {
        return Events.ResolveChoice(choiceId, _clock.Day);
    }

    internal void DebugRestoreNeeds()
    {
        Energy = 100;
        Hunger = 100;
        Thirst = 100;
    }
    internal void Restore(int money, int energy, int hunger, int thirst, int studyXP, bool isSleeping, bool isWorking, bool isStudying, bool isPlaying, bool isSpendingFamilyTime, int awakeMinutesAccumulator, int sleepingMinutesAccumulator, int hungerMinutesAccumulator, int thirstMinutesAccumulator, int workMinutesAccumulator, int studyMinutesAccumulator, int playMinutesAccumulator, int familyTimeMinutesAccumulator)
    {
        Money = money;
        Energy = energy;
        Hunger = hunger;
        Thirst = thirst;
        StudyXP = studyXP;
        IsSleeping = isSleeping;
        IsWorking = isWorking;
        IsStudying = isStudying;
        IsPlaying = isPlaying;
        IsSpendingFamilyTime = isSpendingFamilyTime;
        _awakeMinutesAccumulator = awakeMinutesAccumulator;
        _sleepingMinutesAccumulator = sleepingMinutesAccumulator;
        _hungerMinutesAccumulator = hungerMinutesAccumulator;
        _thirstMinutesAccumulator = thirstMinutesAccumulator;
        _workMinutesAccumulator = workMinutesAccumulator;
        _studyMinutesAccumulator = studyMinutesAccumulator;
        _playMinutesAccumulator = playMinutesAccumulator;
        _familyTimeMinutesAccumulator = familyTimeMinutesAccumulator;
    }

    internal int GetAwakeMinutesAccumulator() => _awakeMinutesAccumulator;
    internal int GetSleepingMinutesAccumulator() => _sleepingMinutesAccumulator;
    internal int GetHungerMinutesAccumulator() => _hungerMinutesAccumulator;
    internal int GetThirstMinutesAccumulator() => _thirstMinutesAccumulator;
    internal int GetWorkMinutesAccumulator() => _workMinutesAccumulator;
    internal int GetStudyMinutesAccumulator() => _studyMinutesAccumulator;
    internal int GetPlayMinutesAccumulator() => _playMinutesAccumulator;
    internal int GetFamilyTimeMinutesAccumulator() => _familyTimeMinutesAccumulator;
}