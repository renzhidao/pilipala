
import 'audio_handler.dart';
import 'audio_session.dart';

late VideoPlayerServiceHandler videoPlayerServiceHandler;
late AudioSessionHandler audioSessionHandler;

// 标记：是否已完成初始化（避免重复初始化 & 竞态）
bool serviceLocatorReady = false;

Future<void> setupServiceLocator() async {
  if (serviceLocatorReady) return;
  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
  serviceLocatorReady = true;
}
