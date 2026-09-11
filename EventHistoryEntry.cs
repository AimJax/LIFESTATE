namespace Lifestate;

public sealed class EventHistoryEntry
{
    public string EventId { get; }
    public string ChoiceId { get; }
    public long TriggeredDay { get; }
    public long ResolvedDay { get; }

    public EventHistoryEntry(string eventId, string choiceId, long triggeredDay, long resolvedDay)
    {
        EventId = eventId;
        ChoiceId = choiceId;
        TriggeredDay = triggeredDay;
        ResolvedDay = resolvedDay;
    }
}
