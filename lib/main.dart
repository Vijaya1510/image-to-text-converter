import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_to_text_coverter_getx/result_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Text Recognition',
      theme: ThemeData(

        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>with WidgetsBindingObserver {

  bool isPermissionGranted = false;


  late final Future<void>_future;

  CameraController ? _cameraController;

  final _textRecognizer = TextRecognizer();

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _future=_requestCameraPermission();
  }


  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _textRecognizer.close();
    super.dispose();

  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(_cameraController== null || !_cameraController!.value.isInitialized){
      return;
    }

    if(state== AppLifecycleState.inactive){
      _stopCamera();
    }else if(state== AppLifecycleState.resumed &&
    _cameraController != null &&
    _cameraController!.value.isInitialized){
      _startCamera();
    }
  }


  @override
  Widget build(BuildContext context){
    return FutureBuilder(
      future: _future,
      builder: (context,snapshot){
        return Stack(
          children: [
            if(isPermissionGranted)
              FutureBuilder<List<CameraDescription>>(
                future: availableCameras(),
                builder: (context,snapshot){
                  if(snapshot.hasData){
                    _initCameraController(snapshot.data!);

                    return Center(child: CameraPreview(_cameraController!));
                  }else{
                    return const LinearProgressIndicator();
                  }
                },

              ),
        Scaffold(
          appBar: AppBar(
            title: const Text('Text Recognition Sample'),
          ),
          backgroundColor: isPermissionGranted ? Colors.transparent:null,
          body: isPermissionGranted ?
              Column(
                children: [
                  Expanded(child: Container(),
                  ),
                  Container(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child:  Center(
                        child: ElevatedButton(
                          onPressed: _scanImage,
                          child:  const Text('scan text'),
                        ),
        ),
                  )
                ],
              )
                  :Center( child:Container(
                   padding: const EdgeInsets.only(left:24.0, right: 24.0),
                    child: const Text('camera permission denied',
                    textAlign: TextAlign.center,),
            ),
          ),
        )
          ],
        );

      });
  }
  Future<void>_requestCameraPermission() async{
    final status= await Permission.camera.request();
    isPermissionGranted = status == PermissionStatus.granted;
  }

  void _startCamera() {
    if (_cameraController != null) {
      _cameraSelected(_cameraController!.description);
    }
  }
  void _stopCamera(){
      if(_cameraController != null){
        _cameraController?.dispose();
      }
  }


  void _initCameraController(List<CameraDescription>? cameras) {
    if (_cameraController != null || cameras == null || cameras.isEmpty) {
      return;
    }

    //select the first rear camera.
    CameraDescription? camera;


    for(var i = 0; i < cameras.length; i++){
      final CameraDescription current = cameras[i];
      if(current.lensDirection == CameraLensDirection.back){
        camera=current;
        break;
      }
    }
    if(camera != null){
      _cameraSelected(camera);
    }
  }
  Future<void> _cameraSelected(CameraDescription camera) async{
    _cameraController=CameraController(camera,
        ResolutionPreset.max,
        enableAudio: false,
    );

    await _cameraController?.initialize();

    if(!mounted){
      return;
    }
    setState(() {});
  }

  Future<void>_scanImage() async{
    if(_cameraController == null)return;

    final navigator = Navigator.of(context);

    try{
      final pictureFile= await _cameraController!.takePicture();

      final file = File(pictureFile.path);

      final inputImage= InputImage.fromFile(file);
      final recognizedText = await _textRecognizer.processImage(inputImage);


      await navigator.push(
      MaterialPageRoute(builder: (context) => ResultScreen(text: recognizedText.text),
      ),
    );

    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:Text('An error occured when scanning text'),
          ),
      );
    }
  }
}

