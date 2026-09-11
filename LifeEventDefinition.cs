namespace Lifestate;

public sealed class LifeEventDefinition
{
    public string Id { get; }
    public string Title { get; }
    public string Description { get; }
    public IReadOnlyList<EventChoice> Choices { get; }

    public LifeEventDefinition(string id, string title, string description, IReadOnlyList<EventChoice> choices)
    {
        Id = id;
        Title = title;
        Description = description;
        Choices = choices;
    }
}
