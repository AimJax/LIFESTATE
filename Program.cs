using System;
using System.Windows.Forms;
using Lifestate;

namespace Lifestate;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            SimulationTests.RunTests();
            return;
        }

        // Test-only save-interchange harness: lets the GDScript suite verify that
        // both implementations read and write the same save format.
        if (SaveInterchangeHarness.TryRun(args)) return;

        ApplicationConfiguration.Initialize();
        var clock = new GameClock();
        var player = new PlayerState(clock);
        Application.Run(new MainForm(player, clock));
    }
}
