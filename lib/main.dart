import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera error: $e");
  }
  runApp(const DoclimaApp());
}

class DoclimaApp extends StatelessWidget {
  const DoclimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doclima Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurple,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ScanScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.document_scanner_rounded,
              size: 90,
              color: Colors.deepPurpleAccent,
            ),
            const SizedBox(height: 20),
            const Text(
              "Doclima Scanner",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.deepPurpleAccent.withOpacity(0.5)),
              ),
              child: const Text(
                "A Product of Doclima Labs",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              color: Colors.deepPurpleAccent,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  List<File> scannedImages = [];
  bool isProcessing = false;
  bool isProUser = false;
  bool isTampered = false;

  @override
  void initState() {
    super.initState();
    _verifyAppSecurity();
    _initCamera();
  }

  Future<void> _verifyAppSecurity() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.packageName != "com.example.doclima_scanner" &&
          packageInfo.packageName != "com.doclimalabs.scanner") {
        setState(() {
          isTampered = true;
          isProUser = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("Security Verification Check: $e");
    }

    setState(() {
      isProUser = prefs.getBool('is_pro_user') ?? false;
    });
  }

  Future<void> _initCamera() async {
    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.max);
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  void _showUpgradeDialog() {
    if (isTampered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Tampered version detected. Upgrade disabled.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text("Doclima Pro"),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("✔ Remove 'Doclima Scanner' Watermark"),
            SizedBox(height: 6),
            Text("✔ High Definition PDF Export"),
            SizedBox(height: 6),
            Text("✔ Ad-Free Premium Experience"),
            SizedBox(height: 6),
            Text("✔ Support Doclima Labs Development"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Maybe Later", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_pro_user', true);
              setState(() {
                isProUser = true;
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Welcome to Doclima Pro!")),
                );
              }
            },
            child: const Text("Upgrade (\$1.99)",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile image = await _controller!.takePicture();
      setState(() {
        scannedImages.add(File(image.path));
      });
    } catch (e) {
      debugPrint("Capture Error: $e");
    }
  }

  Future<void> generatePDF() async {
    if (scannedImages.isEmpty) return;
    setState(() => isProcessing = true);

    final pdf = pw.Document();

    for (var imageFile in scannedImages) {
      final imageBytes = await imageFile.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Image(pdfImage, fit: pw.BoxFit.cover),
                ),
                if (!isProUser || isTampered)
                  pw.Positioned(
                    bottom: 15,
                    right: 15,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.black,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        "Scanned with Doclima Scanner",
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final file = File(
        "${outputDir.path}/Doclima_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());

    setState(() => isProcessing = false);
    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text("Doclima Scanner",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!isProUser)
            IconButton(
              icon: const Icon(Icons.workspace_premium, color: Colors.amber),
              onPressed: _showUpgradeDialog,
            ),
          if (scannedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.greenAccent),
              onPressed: isProcessing ? null : generatePDF,
            ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          if (scannedImages.isNotEmpty)
            Positioned(
              bottom: 110,
              left: 15,
              right: 15,
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: scannedImages.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.deepPurpleAccent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(scannedImages[index],
                            width: 60, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                  child: CircularProgressIndicator(
                      color: Colors.deepPurpleAccent)),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: Colors.white,
        onPressed: captureImage,
        child: const Icon(Icons.camera_alt, color: Colors.black, size: 36),
      ),
    );
  }
}

