# AI-Driven Smart PDF Form Filling in Flutter PDF Viewer example

This repository provides an example of how to seamlessly auto-fill PDF forms using AI integrated with the Flutter PDF Viewer, enabling quick and efficient form completion.

## Process behind smart PDF form filling
The smart PDF form filling process leverages advanced AI models to interpret and extract relevant information from text content, such as paragraphs copied from the clipboard. This data is intelligently mapped to the appropriate fields in a PDF form, including text boxes, checkboxes, list boxes, combo boxes, and radio buttons. This approach significantly reduces the need for manual data entry, making it especially useful for filling out large volumes of forms or handling complex and detailed forms.

## Steps to use the sample

1. Run the application, which loads a default PDF form for filling.
2. Copy text information relevant to the form fields. The application includes three sample text contents that are readily available for copying.
3. Once the text is copied, the "Smart Fill" option will be enabled.
4. Click the "Smart Fill" button to automatically populate the form fields with the copied text content.

**Note:** In the project directory, locate the `api_key.dart` file. Replace the default values in the following code snippet with your specific Google Cloud API Key.

```dart
String apiKey = 'API KEY';
```