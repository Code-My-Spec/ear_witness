# Membrane.Core.LegacyTelemetry



## report_metric/3

Reports metrics such as input buffer's size inside functions, incoming events and received stream format.

## report_bitrate/1

Given list of buffers (or a single buffer) calculates total size of their payloads in bits
and reports it.

## report_link/2

Reports new link connection being initialized in pipeline.

## report_init/1

Reports a pipeline/bin/element initialization.

## report_terminate/1

Reports a pipeline/bin/element termination.