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
    public bool IsSleeping { get; private set; } = false;
    private int _awakeMinutesAccumulator = 0;
    private int _sleepingMinutesAccumulator = 0;
    private int _hungerMinutesAccumulator = 0;

    public void StartSleeping() => IsSleeping = true;
    public void StopSleeping() => IsSleeping = false;

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
}
