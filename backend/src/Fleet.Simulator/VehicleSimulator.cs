namespace Fleet.Simulator;

/// <summary>
/// One simulated vehicle. Deliberately simple (not a physics engine): it drives between random waypoints near its
/// start position, drains its battery while moving, charges when low, switches Idle/Moving now and then, and rarely
/// reports a short fault.
/// </summary>
public class VehicleSimulator(DeviceConfig device, SimulatorOptions options, TelemetrySender sender, ILogger logger)
{
    private const double MetersPerDegreeLatitude = 111_320;
    private const double RoamRadiusMeters = 3_000;
    private const double LowBatteryStartChargingPct = 15;
    private const double ChargedPct = 95;
    private static readonly TimeSpan FaultDuration = TimeSpan.FromSeconds(20);

    private readonly Random _random = new();
    private double _latitude = device.StartLatitude;
    private double _longitude = device.StartLongitude;
    private double _headingDeg;
    private double _speedKmh;
    private double _batteryPct;
    private SimulatedState _state = SimulatedState.Idle;
    private DateTimeOffset _faultEndsAt;
    private (double Lat, double Lon) _waypoint;

    // A real device keeps its counter in flash. Here the first sequence is the current Unix time in ms, so numbers
    // keep increasing across simulator restarts and never collide with samples the API already stored.
    private long _sequence = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        _batteryPct = 25 + _random.NextDouble() * 75;
        _waypoint = RandomWaypoint();
        var isDropoutVehicle = string.Equals(device.SerialNumber, options.DropoutSerial, StringComparison.OrdinalIgnoreCase);
        var nextDropoutAt = DateTimeOffset.UtcNow.AddSeconds(options.DropoutEverySeconds);
        var interval = TimeSpan.FromSeconds(options.IntervalSeconds);

        logger.LogInformation("{Vehicle} ({Serial}) started at {Lat:F4}, {Lon:F4}, battery {Battery:F0}%{Dropout}",
            device.Name, device.SerialNumber, _latitude, _longitude, _batteryPct,
            isDropoutVehicle ? $", drops out for {options.DropoutDurationSeconds}s every {options.DropoutEverySeconds}s" : "");

        using var timer = new PeriodicTimer(interval);
        while (await timer.WaitForNextTickAsync(cancellationToken))
        {
            if (isDropoutVehicle && DateTimeOffset.UtcNow >= nextDropoutAt)
            {
                logger.LogInformation("{Vehicle}: dropout started (no telemetry for {Seconds}s, simulated connection loss)",
                    device.Name, options.DropoutDurationSeconds);
                await Task.Delay(TimeSpan.FromSeconds(options.DropoutDurationSeconds), cancellationToken);
                logger.LogInformation("{Vehicle}: dropout ended, reporting again", device.Name);
                nextDropoutAt = DateTimeOffset.UtcNow.AddSeconds(options.DropoutEverySeconds);
            }

            var previousState = _state;
            Step(interval);
            if (_state != previousState)
            {
                logger.LogInformation("{Vehicle}: {From} → {To} (battery {Battery:F0}%)", device.Name, previousState, _state, _batteryPct);
            }

            await sender.SendAsync(device, Snapshot(), cancellationToken);
        }
    }

    private void Step(TimeSpan elapsed)
    {
        var now = DateTimeOffset.UtcNow;

        if (_state == SimulatedState.Fault)
        {
            if (now >= _faultEndsAt)
            {
                _state = SimulatedState.Idle;
            }

            return;
        }

        if (_random.NextDouble() < 0.01)
        {
            _state = SimulatedState.Fault;
            _faultEndsAt = now + FaultDuration;
            _speedKmh = 0;
            return;
        }

        switch (_state)
        {
            case SimulatedState.Charging:
                _speedKmh = 0;
                _batteryPct = Math.Min(100, _batteryPct + 1.0);
                if (_batteryPct >= ChargedPct)
                {
                    _state = SimulatedState.Idle;
                }

                break;

            case SimulatedState.Idle:
                _speedKmh = 0;
                _batteryPct = Math.Max(0, _batteryPct - 0.01);
                if (_batteryPct < LowBatteryStartChargingPct)
                {
                    _state = SimulatedState.Charging;
                }
                else if (_random.NextDouble() < 0.10)
                {
                    _state = SimulatedState.Moving;
                }

                break;

            case SimulatedState.Moving:
                if (_batteryPct < LowBatteryStartChargingPct)
                {
                    _state = SimulatedState.Charging;
                    _speedKmh = 0;
                }
                else if (_random.NextDouble() < 0.03)
                {
                    _state = SimulatedState.Idle;
                    _speedKmh = 0;
                }
                else
                {
                    Drive(elapsed);
                }

                break;
        }
    }

    private void Drive(TimeSpan elapsed)
    {
        var metersPerDegreeLongitude = MetersPerDegreeLatitude * Math.Cos(_latitude * Math.PI / 180);
        var northMeters = (_waypoint.Lat - _latitude) * MetersPerDegreeLatitude;
        var eastMeters = (_waypoint.Lon - _longitude) * metersPerDegreeLongitude;
        if (Math.Sqrt(northMeters * northMeters + eastMeters * eastMeters) < 30)
        {
            _waypoint = RandomWaypoint();
            return;
        }

        _headingDeg = (Math.Atan2(eastMeters, northMeters) * 180 / Math.PI + 360) % 360;
        _speedKmh = 10 + _random.NextDouble() * 15;
        var distance = _speedKmh / 3.6 * elapsed.TotalSeconds;
        var headingRad = _headingDeg * Math.PI / 180;
        _latitude += distance * Math.Cos(headingRad) / MetersPerDegreeLatitude;
        _longitude += distance * Math.Sin(headingRad) / metersPerDegreeLongitude;
        _batteryPct = Math.Max(0, _batteryPct - 0.25);
    }

    private (double Lat, double Lon) RandomWaypoint()
    {
        // Uniform point in a circle around the start position.
        var distance = RoamRadiusMeters * Math.Sqrt(_random.NextDouble());
        var angle = _random.NextDouble() * 2 * Math.PI;
        var metersPerDegreeLongitude = MetersPerDegreeLatitude * Math.Cos(device.StartLatitude * Math.PI / 180);
        return (device.StartLatitude + distance * Math.Cos(angle) / MetersPerDegreeLatitude,
                device.StartLongitude + distance * Math.Sin(angle) / metersPerDegreeLongitude);
    }

    private TelemetryPayload Snapshot() => new(
        Sequence: _sequence++,
        RecordedAt: DateTimeOffset.UtcNow,
        Latitude: Math.Round(_latitude, 6),
        Longitude: Math.Round(_longitude, 6),
        SpeedKmh: Math.Round(_speedKmh, 1),
        HeadingDeg: Math.Round(_headingDeg, 1) % 360, // rounding 359.96 would give 360, which the API rejects
        BatteryPct: Math.Round(_batteryPct, 1),
        State: _state);
}
