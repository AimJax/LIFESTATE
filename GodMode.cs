using System;

namespace Lifestate;

public class GodMode
{
    private readonly GameClock _clock;
    private readonly PlayerState _player;

    public bool IsEnabled { get; private set; }

    public GodMode(GameClock clock, PlayerState player)
    {
        _clock = clock;
        _player = player;
    }

    public void SetEnabled(bool enabled) => IsEnabled = enabled;

    public void AdvanceDays(int days)
    {
        if (!IsEnabled) return;
        int realSeconds = days * 24 * 60 / GameClock.MinutesPerRealSecond;
        _clock.AdvanceSeconds(realSeconds);
    }

    public void AddMoney(int amount)
    {
        if (!IsEnabled) return;
        _player.DebugAddMoney(amount);
    }

    public void RestoreNeeds()
    {
        if (!IsEnabled) return;
        _player.DebugRestoreNeeds();
    }

    public void MaxAttributes()
    {
        if (!IsEnabled) return;
        _player.Attributes.SetAllMax();
    }

    public void MaxSkills()
    {
        if (!IsEnabled) return;
        _player.Skills.Academics.SetMax();
    }
}
