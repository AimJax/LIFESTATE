namespace Lifestate;

public class PlayerState
{
    private readonly GameClock _clock;

    public PlayerState(GameClock clock)
    {
        _clock = clock;
    }

    public int Age => _clock.Day / 365;
    public int Money { get; set; } = 1000;
    public int Energy { get; set; } = 100;
}