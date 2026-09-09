public class GameClock
{
    private const int MinutesPerRealMinute = 4; // 1 real minute = 4 in-game hours

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
        var inGameMinutesToAdd = realSecondsElapsed * MinutesPerRealMinute;

        // Convert total minutes to hours and days, handling rollovers
        int newHour = Hour + (inGameMinutesToAdd / 60);
        int overflowHours = newHour / 24;
        int newDay = Day + overflowHours;
        newHour %= 24;

        Minute += inGameMinutesToAdd % 60;

        // Assign back to fields
        Hour = newHour;
        Day = newDay;
    }

    public override string ToString() => $"Day {Day}, {Hour:00}:{Minute:00}";
}