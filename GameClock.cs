namespace Lifestate;

public class GameClock
{
    private const int MinutesPerRealSecond = 4; // 1 real second = 4 in-game minutes

    public int Day { get; private set; }
    public int Hour { get; private set; }
    public int Minute { get; private set; }

    public GameClock()
    {
        Day = 0;
        Hour = 0;
        Minute = 0;
    }

    public void AdvanceSeconds(int realSecondsElapsed)
    {
        int inGameMinutesToAdd = realSecondsElapsed * MinutesPerRealSecond;
        int totalMinutes = Minute + inGameMinutesToAdd;
        
        Minute = totalMinutes % 60;
        int hoursToAdd = totalMinutes / 60;
        
        int totalHours = Hour + hoursToAdd;
        Hour = totalHours % 24;
        Day += totalHours / 24;
    }

    public override string ToString() => $"Day {Day}, {Hour:00}:{Minute:00}";
}