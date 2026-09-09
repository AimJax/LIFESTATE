namespace Lifestate;

public class GameClock
{
    public const int MinutesPerRealSecond = 4; // 1 real second = 4 in-game minutes

    public int Day { get; private set; }
    public int Year => Day / 365;
    public int DayOfYear => Day % 365;
    public int Hour { get; private set; }
    public int Minute { get; private set; }

    public GameClock()
    {
        Day = 0;
        Hour = 0;
        Minute = 0;
    }

    public void AdvanceGameMinutes(long minutes)
    {
        if (minutes < 0) return;

        long totalMinutes = Minute + minutes;

        Minute = (int)(totalMinutes % 60);
        long hoursToAdd = totalMinutes / 60;

        long totalHours = Hour + hoursToAdd;
        Hour = (int)(totalHours % 24);
        Day += (int)(totalHours / 24);
    }

    public void AdvanceSeconds(int realSecondsElapsed)
    {
        AdvanceGameMinutes((long)realSecondsElapsed * MinutesPerRealSecond);
    }

    public override string ToString() => $"Day {Day}, {Hour:00}:{Minute:00}";
    internal void Restore(int day, int hour, int minute)
    {
        Day = day;
        Hour = hour;
        Minute = minute;
    }

}