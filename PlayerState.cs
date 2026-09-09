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
    private int _energyMinutesAccumulator = 0;

    public void UpdateEnergy(int elapsedMinutes)
    {
        _energyMinutesAccumulator += elapsedMinutes;
        int energyToLose = _energyMinutesAccumulator / 60;
        
        if (energyToLose > 0)
        {
            Energy = Math.Max(0, Energy - energyToLose);
            _energyMinutesAccumulator %= 60;
        }
    }
}