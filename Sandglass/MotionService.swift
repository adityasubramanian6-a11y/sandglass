import CoreMotion

/// Reads gravity from CoreMotion (accelerometer + gyroscope fusion) and exposes it
/// in screen coordinates: x to the right, y towards the bottom of the screen.
/// The length of the vector is how much of gravity lies in the screen's plane:
/// about 1 when the phone stands upright, about 0 when it lies flat on a table.
final class MotionService {
    private let manager = CMMotionManager()
    private(set) var screenGravity = Vec(x: 0, y: 1)

    func start() {
        if manager.isDeviceMotionAvailable {
            guard !manager.isDeviceMotionActive else { return }
            manager.deviceMotionUpdateInterval = 1.0 / 60.0
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let g = motion?.gravity else { return }
                self?.screenGravity = Vec(x: g.x, y: -g.y)
            }
        } else if manager.isAccelerometerAvailable {
            // Older hardware without device-motion fusion: low-pass the raw accelerometer.
            guard !manager.isAccelerometerActive else { return }
            manager.accelerometerUpdateInterval = 1.0 / 60.0
            manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let a = data?.acceleration else { return }
                let raw = Vec(x: a.x, y: -a.y)
                self.screenGravity = self.screenGravity * 0.85 + raw * 0.15
            }
        }
        // The Simulator has neither, so gravity stays pointing down the screen;
        // tapping the hourglass turns it over instead.
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        manager.stopAccelerometerUpdates()
    }
}
