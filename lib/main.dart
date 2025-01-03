import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'api_key.dart';
import 'save_helper/save_helper.dart'
    if (dart.library.js_interop) 'save_helper/save_helper_web.dart';

void main() {
  runApp(
    const MaterialApp(
      home: SmartPDFFormFill(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class SmartPDFFormFill extends StatefulWidget {
  const SmartPDFFormFill({super.key});

  @override
  State<SmartPDFFormFill> createState() => _SmartPDFFormFillState();
}

class _SmartPDFFormFillState extends State<SmartPDFFormFill>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _isExpanded = false;
  final Map<int, bool> _isCopied = {};
  bool _isButtonEnabled = false;

  /// Boolean to indicate whether the AI service work is in progress
  bool _isBusy = false;
  bool _isDocumentLoaded = false;

  /// To check platform whether it is desktop or not.
  bool kIsDesktop =
      kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Indicates whether the application is viewed on an mobile view or desktop view.
  bool _isMobileView = false;

  final List<String> _userDetails = [];
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true); // Repeats the animation back and forth

    // Define the animation
    _animation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeInOutCubic),
    );

    // Show the dialog when the app starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (apiKey.isEmpty || apiKey == 'API KEY') {
        _showDialog('Error',
            'Please provide a Google Cloud API Key in the `api_key.dart` file and perform a hot restart. You can also continue with offline data.');
      } else {
        try {
          _initAiServices(apiKey);
        } catch (e) {
          _showDialog('Error', e.toString());
        }
      }
    });
    _initUserDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMobileView = (kIsDesktop && MediaQuery.sizeOf(context).width < 700);
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Initialize the AI services with the provided API key
  void _initAiServices(String apiKey) {
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: apiKey,
      );

      _chat = _model.startChat();
    } catch (e) {
      _showDialog('Error', 'Failed to initialize AI services: ${e.toString()}');
    }
  }

  /// Enables the Smart fill button if the clipboard has any values
  Future<void> _checkClipboard() async {
    try {
      final ClipboardData? clipboardData =
          await Clipboard.getData('text/plain');

      final String? clipboardContent = clipboardData?.text;

      if (clipboardContent != null) {
        setState(() {
          _isButtonEnabled = _userDetails.contains(clipboardContent);
        });
      }
    } catch (e) {
      setState(() {
        _isBusy = false;
      });
      _showDialog('Error', e.toString());
    }
  }

  /// Initialize sample user details
  void _initUserDetails() {
    _userDetails.add(
        'Hi, this is John. You can contact me at john123@emailid.com. I am male, born on February 20, 2005. I want to subscribe to a newspaper and learn courses, specifically a Machine Learning course. I am from Alaska.');
    _userDetails.add(
        'S David here. You can reach me at David123@emailid.com. I am male, born on March 15, 2003. I would like to subscribe to a newspaper and am interested in taking a Digital Marketing course. I am from New York.');
    _userDetails.add(
        'Hi, this is Alice. You can contact me at alice456@emailid.com. I am female, born on July 15, 1998. I want to unsubscribe from a newspaper and learn courses, specifically a Cloud Computing course. I am from Texas.');
  }

  /// Send message to the AI service
  Future<String?> _sendMessage(String message) async {
    try {
      final GenerateContentResponse response =
          await _chat.sendMessage(Content.text(message));
      return response.text;
    } catch (e) {
      _showDialog('Error', e.toString());
      return null;
    }
  }

  /// Set the copied content to the clipboard
  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Execute smart fill based on the API key.
  Future<void> _smartFill() async {
    try {
      final ClipboardData? clipboardData = await _getClipboardContent();
      if (!_validateClipboardContent(clipboardData)) return;
      setState(() {
        _isBusy = true;
      });

      final String copiedTextContent = clipboardData!.text!;
      await _processSmartFillRequest(copiedTextContent);
    } catch (e) {
      _showDialog('Error', e.toString());
      setState(() {
        _isBusy = false;
      });
    }
  }

  /// Get the content from the clipboard.
  Future<ClipboardData?> _getClipboardContent() async {
    return await Clipboard.getData('text/plain');
  }

  /// Validate the clipboard content.
  bool _validateClipboardContent(ClipboardData? clipboardData) {
    return clipboardData != null && clipboardData.text != null;
  }

  /// Process the request based in the availability of the API key.
  /// If no API key is provided, the request will be processed offline with the predefined data.
  /// If API key is provided, the request will be provessed by the AI service.
  Future<void> _processSmartFillRequest(String copiedTextContent) async {
    String? response;
    if (apiKey.isNotEmpty && apiKey != 'API KEY') {
      response = await _processWithAI(copiedTextContent);
    } else {
      response = _processWithOfflineData(copiedTextContent);
    }

    if (response != null && response.isNotEmpty) {
      _fillPDF(response);
    } else {
      setState(() {
        _isBusy = false;
      });
    }
  }

  /// To process the request using AI service.
  Future<String?> _processWithAI(String copiedTextContent) async {
    final String customValues = _getHintText();
    final String exportedFormData = _getXFDFString();

    final String prompt = '''
    Merge the copied text content into the XFDF file content. Hint text: $customValues.
    Ensure the copied text content matches the appropriate field names.
    Here are the details:
    Copied text content: $copiedTextContent,
    XFDF information: $exportedFormData.
    Provide the resultant XFDF directly.
    Please follow these conditions:
    1. The input data is not directly provided as the field name; you need to think and merge appropriately.
    2. When comparing input data and field names, ignore case sensitivity.
    3. First, determine the best match for the field name. If there isn't an exact match, use the input data to find a close match.
    4. Remove the xml code tags if they are present in the first and last lines of the code.''';

    return await _sendMessage(prompt);
  }

  /// To get the predefiend responses when no API key is provided
  String _processWithOfflineData(String data) {
    String response = '';
    if (data.compareTo(_userDetails[0]) == 0) {
      response = '''
                <?xml version="1.0" encoding="utf-8"?>
                <xfdf xmlns="http://ns.adobe.com/xfdf/" xml:space="preserve">
                  <fields>
                    <field name="name">
                      <value>John</value>
                    </field>
                    <field name="email">
                      <value>john123@emailid.com</value>
                    </field>
                    <field name="gender">
                      <value>Male</value>
                    </field>
                    <field name="dob">
                      <value>Feb/20/2005</value>
                    </field>
                    <field name="state">
                      <value>Alaska</value>
                    </field>
                    <field name="newsletter">
                      <value>On</value>
                    </field>
                    <field name="courses">
                      <value>Machine Learning</value>
                    </field>
                  </fields>
                  <f href=""/>
                </xfdf>
                ''';
    } else if (data.compareTo(_userDetails[1]) == 0) {
      response = '''
                <?xml version="1.0" encoding="utf-8"?>
                <xfdf xmlns="http://ns.adobe.com/xfdf/" xml:space="preserve">
                  <fields>
                    <field name="name">
                      <value>S David</value>
                    </field>
                    <field name="email">
                      <value>David123@emailid.com</value>
                    </field>
                    <field name="gender">
                      <value>Male</value>
                    </field>
                    <field name="dob">
                      <value>Mar/15/2003</value>
                    </field>
                    <field name="state">
                      <value>New York</value>
                    </field>
                    <field name="newsletter">
                      <value>On</value>
                    </field>
                    <field name="courses">
                      <value>Digital Marketing</value>
                    </field>
                  </fields>
                  <f href=""/>
                </xfdf>
                ''';
    } else if (data.compareTo(_userDetails[2]) == 0) {
      response = '''
                <?xml version="1.0" encoding="utf-8"?>
                <xfdf xmlns="http://ns.adobe.com/xfdf/" xml:space="preserve">
                  <fields>
                    <field name="name">
                      <value>Alice</value>
                    </field>
                    <field name="email">
                      <value>alice456@emailid.com</value>
                    </field>
                    <field name="gender">
                      <value>Female</value>
                    </field>
                    <field name="dob">
                      <value>Jul/15/1998</value>
                    </field>
                    <field name="state">
                      <value>Texas</value>
                    </field>
                    <field name="newsletter">
                      <value>Off</value>
                    </field>
                    <field name="courses">
                      <value>Cloud Computing</value>
                    </field>
                  </fields>
                  <f href=""/>
                </xfdf>
                ''';
    }

    return response;
  }

  /// Fill the PDF form by importing the xfdf content
  Future<void> _fillPDF(String xfdfString) async {
    const utf8 = Utf8Codec();
    final List<int> xfdfBytes = utf8.encode(xfdfString);
    _pdfViewerController.importFormData(xfdfBytes, DataFormat.xfdf);
    setState(() {
      _isBusy = false;
    });
  }

  /// Converts the form data to String.
  String _getXFDFString() {
    final List<int> xfdfBytes =
        _pdfViewerController.exportFormData(dataFormat: DataFormat.xfdf);
    const utf8 = Utf8Codec();
    final String xfdfString = utf8.decode(xfdfBytes);
    return xfdfString;
  }

  /// Get the options available for the combo box, radio button and list box fields.
  String _getHintText() {
    final List<PdfFormField> fields = _pdfViewerController.getFormFields();

    String hintData = '';
    for (final PdfFormField field in fields) {
      // Check if the form field is a ComboBox
      if (field is PdfComboBoxFormField) {
        // Append ComboBox name and items to the hintData string
        hintData += '\n${field.name} : Collection of Items are : ';
        for (final String item in field.items) {
          hintData += '$item, ';
        }
      }
      // Check if the form field is a RadioButton
      else if (field is PdfRadioFormField) {
        // Append RadioButton name and items to the hintData string
        hintData += '${'\n${field.name}'} : Collection of Items are : ';
        for (final String item in field.items) {
          hintData += '$item, ';
        }
      }
      // Check if the form field is a ListBox
      else if (field is PdfListBoxFormField) {
        // Append ListBox name and items to the hintData string
        hintData += '${'\n${field.name}'} : Collection of Items are : ';
        for (final String item in field.items) {
          hintData += '$item, ';
        }
      }
      // Check if the form field name contains 'Date', 'dob', or 'date'
      else if (field.name.contains('Date') ||
          field.name.contains('dob') ||
          field.name.contains('date')) {
        // Append instructions for date format to the hintData string
        hintData += '${'\n${field.name}'} : Write Date in MMM/dd/YYYY format';
      }
      // Append other form field names to the hintData string
      else {
        hintData += 'Can you please enter :\n${field.name}';
      }
    }
    return hintData;
  }

  /// Save the document locally
  Future<void> _saveDocument(List<int> dataBytes, String fileName) async {
    try {
      final path = await FileSaveHelper.saveFile(dataBytes, fileName);
      if (kIsWeb) {
        _showDialog('Document saved',
            'The document was saved in the Downloads folder.');
      } else {
        _showDialog(
            'Document saved', 'The document was saved at the location:\n$path');
      }
    } on PathAccessException catch (e) {
      _showDialog(
          'Error', e.osError?.message ?? 'Error in saving the document');
    } catch (e) {
      _showDialog('Error', 'Error in saving the document');
    }
  }

  /// Show Alert dialog with Title and message.
  /// Used for save and for any error messages.
  void _showDialog(String title, String message) {
    showDialog<Widget>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 328.0,
              child: Scrollbar(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  child: Text(message),
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  fixedSize: const Size(double.infinity, 40),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                ),
                child: const Text('Close'),
              )
            ],
            contentPadding: const EdgeInsets.only(
              left: 24.0,
              top: 16.0,
              right: 24.0,
            ),
            actionsPadding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          );
        });
  }

  /// To save the PDF document
  Future<void> _saveDocumentHandler() async {
    final List<int> savedBytes = await _pdfViewerController.saveDocument();
    _saveDocument(savedBytes, 'form.pdf');
  }

  @override
  Widget build(BuildContext context) {
    var mediaQueryData = MediaQuery.of(context);

    // Determine if the device is mobile and in portrait mode or a non-web environment.
    final isMobile = _isMobileView ||
        (!kIsDesktop && mediaQueryData.orientation == Orientation.portrait);

    // Determine the width of the list panel based on device type and orientation.
    final listWidth = kIsDesktop
        ? mediaQueryData.size.width / 4
        : mediaQueryData.size.width / 3;

    var themeData = Theme.of(context);

    // Function to build the PDF viewer widget.
    Widget pdfViewer() {
      return Stack(
        children: [
          // Display PDF from the asset using SfPdfViewer.
          SfPdfViewer.asset(
            'assets/smart-form.pdf',
            controller: _pdfViewerController,
            key: _pdfViewerKey,
            initialScrollOffset: const Offset(0, 110),
            onDocumentLoaded: (details) {
              // Export empty fields in the form.
              details.document.form.exportEmptyFields = true;
              setState(() => _isDocumentLoaded = true);
              _checkClipboard();
            },
          ),
          // Save Button
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: FloatingActionButton(
                heroTag: 'Save',
                onPressed: _saveDocumentHandler,
                child: Icon(Icons.save,
                    color: themeData.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          // Display loading indicator when busy.
          if (_isBusy)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }

    // Build individual list item card.
    Widget listItem(int index) {
      return Card(
        shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade300),
            borderRadius: const BorderRadius.all(Radius.circular(16.0))),
        margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: index == 0 ? 16 : 8,
          bottom: index == _userDetails.length - 1 ? 16 : 8,
        ),
        elevation: 4,
        child: Padding(
          padding: isMobile
              ? const EdgeInsets.all(16.0)
              : const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(_userDetails[index],
                    style: themeData.textTheme.bodyMedium?.copyWith(
                        color: themeData.colorScheme.onSurfaceVariant)),
              ),
              Padding(
                padding: isMobile
                    ? const EdgeInsets.only(left: 16.0)
                    : const EdgeInsets.only(left: 12.0),
                child: Tooltip(
                  message: 'Copy',
                  child: GestureDetector(
                    onTap: () {
                      // Copy the data to clipboard and update UI.
                      _copyToClipboard(_userDetails[index]);
                      setState(() {
                        _isCopied[index] = true;
                        _isButtonEnabled = true;
                      });
                      Future.delayed(const Duration(seconds: 1), () {
                        setState(() => _isCopied[index] = false);
                      });
                    },
                    child: Icon(
                      // Show check or copy icon based on whether data is copied.
                      _isCopied[index] ?? false ? Icons.check : Icons.copy,
                      key: ValueKey(_isCopied[index] ?? false
                          ? 'check_$index'
                          : 'copy_$index'),
                      color: themeData.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build the list view of items.
    Widget listView() {
      return Visibility(
        visible: _isDocumentLoaded,
        child: ListView.builder(
          itemCount: _userDetails.length,
          itemBuilder: (context, index) => listItem(index),
        ),
      );
    }

    /// Build the AppBar
    AppBar appBar() {
      return AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Smart Fill'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildSmartFillButton(themeData),
          )
        ],
        elevation: 2.0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(
            height: 0.75,
            color: themeData.colorScheme.outlineVariant,
          ),
        ),
      );
    }

    return isMobile
        ? Scaffold(
            appBar: appBar(),
            body: Column(
              children: [
                Expanded(flex: 4, child: pdfViewer()),
                Visibility(
                  visible: _isDocumentLoaded,
                  child: Flexible(
                    flex: _isExpanded ? 4 : 2,
                    child: Column(
                      children: [
                        InkWell(
                          splashColor: Colors.transparent,
                          onTap: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                    color:
                                        themeData.colorScheme.outlineVariant),
                                bottom: BorderSide(
                                    color:
                                        themeData.colorScheme.outlineVariant),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8.0, bottom: 4.0),
                                  child: Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_down
                                        : Icons.keyboard_arrow_up,
                                    color:
                                        themeData.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 4.0, bottom: 8.0),
                                  child: Text(
                                    'Sample Content to copy',
                                    style: TextStyle(
                                      color: themeData
                                          .colorScheme.onSurfaceVariant,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: listView()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : Material(
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                      child: Scaffold(appBar: appBar(), body: pdfViewer())),
                  VerticalDivider(
                    color: themeData.colorScheme.outlineVariant,
                    width: 1.0,
                  ),
                  // Display the list panel next to PDF viewer on larger screens.
                  SizedBox(
                    width: listWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: themeData.colorScheme.outlineVariant,
                                  width: 0.75),
                            ),
                          ),
                          height: 56.0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Sample Content to copy',
                                    style: TextStyle(
                                      color: themeData
                                          .colorScheme.onSurfaceVariant,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: listView()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  /// Build the Smart fill button with animation
  Widget _buildSmartFillButton(ThemeData themeData) {
    return Tooltip(
      message: _isButtonEnabled ? 'Click to smart fill the form' : '',
      child: AnimatedBuilder(
        animation: _animation,
        builder: (BuildContext context, Widget? child) {
          return Transform.scale(
            scale: _isButtonEnabled ? _animation.value : 1,
            child: ElevatedButton(
              onPressed: _isButtonEnabled ? _smartFill : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: themeData.colorScheme.primary,
                  padding: kIsDesktop
                      ? const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 24.0)
                      : null),
              child: Text('Smart Fill',
                  style: TextStyle(color: themeData.colorScheme.onPrimary)),
            ),
          );
        },
      ),
    );
  }
}
