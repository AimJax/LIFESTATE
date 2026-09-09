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

        ApplicationConfiguration.Initialize();
        var clock = new GameClock();
        var player = new PlayerState(clock);
        Application.Run(new MainForm(player, clock));
    }
}
