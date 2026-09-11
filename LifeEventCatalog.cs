namespace Lifestate;

public static class LifeEventCatalog
{
    public const string FirstDaySchoolId = "childhood.first_day_school";
    public const string BrokenToyId = "childhood.broken_toy";
    public const string FoundMoneyId = "childhood.found_money";

    private static readonly List<LifeEventDefinition> _definitions = new()
    {
        new LifeEventDefinition(
            FirstDaySchoolId,
            "First Day of School",
            "It's your first day of school. The classroom is full of unfamiliar faces.",
            new List<EventChoice>
            {
                new EventChoice("stay_quiet", "Stay quiet and observe."),
                new EventChoice("introduce_yourself", "Introduce yourself to the other children.")
            }),

        new LifeEventDefinition(
            BrokenToyId,
            "Broken Toy",
            "One of your favorite toys breaks while you're playing.",
            new List<EventChoice>
            {
                new EventChoice("try_fix", "Try to fix it yourself."),
                new EventChoice("ask_parent", "Ask your parents for help.")
            }),

        new LifeEventDefinition(
            FoundMoneyId,
            "Found Money",
            "You find some money on the ground with nobody around.",
            new List<EventChoice>
            {
                new EventChoice("keep_money", "Keep the money."),
                new EventChoice("give_parent", "Give it to your parents.")
            })
    };

    // Deterministic priority order: First Day of School, Broken Toy, Found Money.
    private static readonly List<string> _priorityOrder = new()
    {
        FirstDaySchoolId,
        BrokenToyId,
        FoundMoneyId
    };

    public static IReadOnlyList<LifeEventDefinition> Definitions => _definitions;

    public static LifeEventDefinition? GetById(string eventId)
    {
        foreach (var definition in _definitions)
        {
            if (definition.Id == eventId) return definition;
        }
        return null;
    }

    public static bool IsKnownEvent(string eventId) => GetById(eventId) != null;

    public static bool IsKnownChoice(string eventId, string choiceId)
    {
        var definition = GetById(eventId);
        if (definition == null) return false;
        foreach (var choice in definition.Choices)
        {
            if (choice.Id == choiceId) return true;
        }
        return false;
    }
}
