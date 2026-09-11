namespace Lifestate;

public sealed class PendingLifeEvent
{
    public string EventId { get; }
    public long TriggeredDay { get; }

    public PendingLifeEvent(string eventId, long triggeredDay)
    {
        EventId = eventId;
        TriggeredDay = triggeredDay;
    }
}
