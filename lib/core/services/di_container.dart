import 'package:get_it/get_it.dart';
import 'package:mobile_ai_photo_editor/features/presentation/bloc/editor_cubit.dart';

final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  if (!sl.isRegistered<EditorCubit>()) {
    sl.registerFactory<EditorCubit>(() => EditorCubit());
  }
}
