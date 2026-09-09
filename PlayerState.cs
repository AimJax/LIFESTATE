namespace Lifestate;

public class PlayerState
{
    private readonly GameClock _clock;

    public PlayerState(GameClock clock)
    {
        _clock = clock;
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

    public int Money { get; set; } = 1000;
    public int Energy { get; private set; } = 100;
    public int Hunger { get; private set; } = 100;
    public int Thirst { get; private set; } = 100;
    public int StudyXP { get; private set; } = 0;
    public bool IsSleeping { get; private set; } = false;
    public bool IsWorking { get; private set; } = false;
    public bool IsStudying { get; private set; } = false;

    private int _awakeMinutesAccumulator = 0;
    private int _sleepingMinutesAccumulator = 0;
    private int _hungerMinutesAccumulator = 0;
    private int _thirstMinutesAccumulator = 0;
    private int _workMinutesAccumulator = 0;
    private int _studyMinutesAccumulator = 0;

    public void StartSleeping()
    {
        if (IsWorking || IsStudying) return;
        IsSleeping = true;
    }
    public void StopSleeping() => IsSleeping = false;

    public void StartWorking()
    {
        if (Age < 18 || IsSleeping || IsStudying) return;
        IsWorking = true;
    }
    public void StopWorking() => IsWorking = false;

    public void StartStudying()
    {
        if (Age < 6 || IsSleeping || IsWorking) return;
        IsStudying = true;
    }
    public void StopStudying() => IsStudying = false;

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

    internal void DebugRestoreNeeds()
    {
        Energy = 100;
        Hunger = 100;
        Thirst = 100;
    }
    internal void Restore(int money, int energy, int hunger, int thirst, int studyXP, bool isSleeping, bool isWorking, bool isStudying, int workMinutesAccumulator, int studyMinutesAccumulator)
    {
        Money = money;
        Energy = energy;
        Hunger = hunger;
        Thirst = thirst;
        StudyXP = studyXP;
        IsSleeping = isSleeping;
        IsWorking = isWorking;
        IsStudying = isStudying;
        _workMinutesAccumulator = workMinutesAccumulator;
        _studyMinutesAccumulator = studyMinutesAccumulator;
    }

    internal int GetWorkMinutesAccumulator() => _workMinutesAccumulator;
    internal int GetStudyMinutesAccumulator() => _studyMinutesAccumulator;
}

