import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/record_bloc.dart';
import '../../bloc/record_event.dart';
import '../../bloc/record_state.dart' show RecorderState;
import '../widgets/opusamp_transport_panel.dart';

class RecordAndPlaybackScreenWidget extends StatelessWidget {
  const RecordAndPlaybackScreenWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RecordBloc(),
      child: const _RecordAndPlaybackView(),
    );
  }
}

class _RecordAndPlaybackView extends StatelessWidget {
  const _RecordAndPlaybackView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: BlocBuilder<RecordBloc, RecorderState>(
              builder: (context, state) {
                final bloc = context.read<RecordBloc>();
                return OpusampTransportPanel(
                  phase: state.phase,
                  statusText: state.statusText,
                  opusStorage: state.opusStorage,
                  wavStorage: state.wavStorage,
                  onRecord: state.phase.isIdle
                      ? () => bloc.add(const StartRecordingEvent())
                      : null,
                  onStop: state.phase.isRecording
                      ? () => bloc.add(const StopRecordingEvent())
                      : null,
                  onDecode: state.phase.isIdle && state.opusStorage != null
                      ? () => bloc.add(const DecodeFromDiskEvent())
                      : null,
                  onPlay: state.phase.isIdle && state.wavReady
                      ? () => bloc.add(const PlayDecodedFileEvent())
                      : null,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
