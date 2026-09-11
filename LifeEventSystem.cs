namespace Lifestate;

/// <summary>
/// Owns runtime event state (pending event + resolved history) for one player.
/// Definitions stay immutable in LifeEventCatalog; this class only tracks
/// runtime state and applies deterministic, explicit outcomes. No randomness.
/// </summary>
public sealed class LifeEventSystem
{
    private readonly PlayerState _player;
    private readonly List<EventHistoryEntry> _history = new();

    public PendingLifeEvent? CurrentEvent { get; private set; }
    public IReadOnlyList<EventHistoryEntry> History => _history;

    public LifeEventSystem(PlayerState player)
    {
        _player = player;
    }

    /// <summary>
    /// Deterministic trigger evaluation. At most one pending event may exist.
    /// If multiple events are eligible, the highest-priority one triggers
    /// (First Day of School, then Broken Toy, then Found Money).
    /// TriggeredDay is the CURRENT day, even if eligibility began earlier.
    /// </summary>
    internal void EvaluateTriggers(long currentDay)
    {
        if (CurrentEvent != null) return;

        if (IsEligibleFirstDay() && !IsBlocked(LifeEventCatalog.FirstDaySchoolId))
        {
            CurrentEvent = new PendingLifeEvent(LifeEventCatalog.FirstDaySchoolId, currentDay);
            return;
        }

        if (IsEligibleBrokenToy() && !IsBlocked(LifeEventCatalog.BrokenToyId))
        {
            CurrentEvent = new PendingLifeEvent(LifeEventCatalog.BrokenToyId, currentDay);
            return;
        }

        if (IsEligibleFoundMoney() && !IsBlocked(LifeEventCatalog.FoundMoneyId))
        {
            CurrentEvent = new PendingLifeEvent(LifeEventCatalog.FoundMoneyId, currentDay);
        }
    }

    private bool IsEligibleFirstDay()
        => _player.Age >= 6 && _player.Education.Status == EducationStatus.PrimarySchool;

    private bool IsEligibleBrokenToy()
        => _player.Age >= 4 && _player.TotalPlayHours >= 10;

    private bool IsEligibleFoundMoney()
        => _player.Age >= 8;

    /// <summary>One-shot events never trigger again once pending or resolved.</summary>
    private bool IsBlocked(string eventId)
    {
        if (CurrentEvent != null && CurrentEvent.EventId == eventId) return true;
        foreach (var entry in _history)
        {
            if (entry.EventId == eventId) return true;
        }
        return false;
    }

    /// <summary>
    /// Controlled resolution: validate event + choice FIRST, then apply the
    /// exact deterministic outcome, append one history entry, clear pending.
    /// Invalid input mutates nothing and returns false.
    /// </summary>
    public bool ResolveChoice(string choiceId, long currentDay)
    {
        if (CurrentEvent == null) return false;

        string eventId = CurrentEvent.EventId;
        long triggeredDay = CurrentEvent.TriggeredDay;

        var definition = LifeEventCatalog.GetById(eventId);
        if (definition == null) return false;
        if (!LifeEventCatalog.IsKnownChoice(eventId, choiceId)) return false;

        // Validation complete — apply explicit deterministic outcome.
        switch (eventId, choiceId)
        {
            case (LifeEventCatalog.FirstDaySchoolId, "stay_quiet"):
                _player.Traits.AddPatience(1.0);
                _player.Traits.AddConfidence(-0.5);
                break;

            case (LifeEventCatalog.FirstDaySchoolId, "introduce_yourself"):
                _player.Traits.AddConfidence(1.0);
                _player.Attributes.AddSocial(0.5);
                break;

            case (LifeEventCatalog.BrokenToyId, "try_fix"):
                _player.Attributes.AddCreativity(1.0);
                _player.Traits.AddPatience(0.5);
                break;

            case (LifeEventCatalog.BrokenToyId, "ask_parent"):
                _player.Relationships.MotherRelationship.AddCloseness(0.5);
                _player.Relationships.FatherRelationship.AddCloseness(0.5);
                _player.Traits.AddEmpathy(0.5);
                break;

            case (LifeEventCatalog.FoundMoneyId, "keep_money"):
                _player.AddMoneySafely(25);
                _player.Traits.AddEmpathy(-0.5);
                break;

            case (LifeEventCatalog.FoundMoneyId, "give_parent"):
                _player.Traits.AddEmpathy(1.0);
                _player.Relationships.MotherRelationship.AddCloseness(0.5);
                _player.Relationships.FatherRelationship.AddCloseness(0.5);
                break;

            default:
                // Exhaustive switch over the catalog; unreachable by validation.
                return false;
        }

        _history.Add(new EventHistoryEntry(eventId, choiceId, triggeredDay, currentDay));
        CurrentEvent = null;
        return true;
    }

    /// <summary>Controlled internal clear of pending state (transactional commit path).</summary>
    internal void ClearPending()
    {
        CurrentEvent = null;
    }

    /// <summary>Controlled internal restore of pending state. Unknown event IDs no-op.</summary>
    internal void RestorePending(string eventId, long triggeredDay)
    {
        if (CurrentEvent != null) return;
        if (!LifeEventCatalog.IsKnownEvent(eventId)) return;
        if (triggeredDay < 0) return;
        // Defense in depth: never restore a pending event that is already resolved.
        if (HasResolved(eventId)) return;

        CurrentEvent = new PendingLifeEvent(eventId, triggeredDay);
    }

    /// <summary>
    /// Controlled internal restore of history. All-or-nothing: if any entry is
    /// invalid, the whole restore no-ops and state remains unchanged.
    /// Order is preserved exactly as provided.
    /// </summary>
    internal void RestoreHistory(IReadOnlyList<EventHistoryEntry> entries)
    {
        if (entries == null) return;

        var seen = new HashSet<string>();
        foreach (var entry in entries)
        {
            if (entry == null) return;
            if (!LifeEventCatalog.IsKnownEvent(entry.EventId)) return;
            if (!LifeEventCatalog.IsKnownChoice(entry.EventId, entry.ChoiceId)) return;
            if (entry.TriggeredDay < 0) return;
            if (entry.ResolvedDay < entry.TriggeredDay) return;
            if (!seen.Add(entry.EventId)) return; // one-shot: duplicates invalid
        }

        _history.Clear();
        _history.AddRange(entries);
    }

    internal bool HasResolved(string eventId)
    {
        foreach (var entry in _history)
        {
            if (entry.EventId == eventId) return true;
        }
        return false;
    }
}
