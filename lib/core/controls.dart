/// What the player is doing with the controls this frame.
///
/// Touch controls and the keyboard both write here; a simulation only
/// reads it, which keeps the simulations free of input code.
class ControlState {
  /// -1 (left) .. 1 (right).
  double stickX = 0;

  /// -1 (down / dive) .. 1 (up / climb).
  double stickY = 0;

  /// Held while the guns should fire.
  bool fire = false;

  /// Set for exactly one frame when a bomb is requested.
  bool drop = false;

  void reset() {
    stickX = 0;
    stickY = 0;
    fire = false;
    drop = false;
  }
}
