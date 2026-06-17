<!--
Thanks for contributing! A few quick checks before you open this — see
CONTRIBUTING.md for the full version.
-->

## What this changes

<!-- A short description of the change and why. -->

## Checklist

- [ ] I did **not** modify the audio DSP (`AirwindowsAUv3/AirwindowsDSP/Airwin/`) — it's Chris Johnson's work and off-limits.
- [ ] Metadata corrections (categories, descriptions, links) go through the JSON override layer in `AirwindowsDSP/Resources/`, not direct edits to regenerated upstream files.
- [ ] New entry-point source files have a header comment explaining their role (code accessibility is a project goal).
- [ ] Builds locally (`xcodegen generate` + build in Xcode), and CI is green.

## Tested

<!-- How you verified it. On-device testing in a host (AUM, Logic, etc.) is
the gold standard; note the iPad/host if relevant. -->
