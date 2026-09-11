namespace Lifestate;

public sealed class EventChoice
{
    public string Id { get; }
    public string Text { get; }

    public EventChoice(string id, string text)
    {
        Id = id;
        Text = text;
    }
}
