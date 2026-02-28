package com.feuillet.app

import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SafMethodChannel(private val activity: MainActivity) {
    companion object {
        private const val CHANNEL = "com.feuillet.app/saf"
        private const val REQUEST_OPEN_DOCUMENT_TREE = 1001
    }

    private var pendingResult: MethodChannel.Result? = null

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> pickDirectory(result)
                    "listDocumentFiles" -> listDocumentFiles(call, result)
                    "readFileBytes" -> readFileBytes(call, result)
                    "copyToLocal" -> copyToLocal(call, result)
                    "writeFile" -> writeFile(call, result)
                    "getFileMetadata" -> getFileMetadata(call, result)
                    "deleteFile" -> deleteFile(call, result)
                    "fileExists" -> fileExists(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        activity.startActivityForResult(intent, REQUEST_OPEN_DOCUMENT_TREE)
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_OPEN_DOCUMENT_TREE) return false
        val result = pendingResult ?: return true
        pendingResult = null

        if (resultCode != android.app.Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return true
        }

        val treeUri = data.data!!
        // Take persistable permission so the URI survives app restarts
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        activity.contentResolver.takePersistableUriPermission(treeUri, flags)

        result.success(treeUri.toString())
        return true
    }

    private fun listDocumentFiles(call: MethodCall, result: MethodChannel.Result) {
        val treeUriStr = call.argument<String>("treeUri")
        if (treeUriStr == null) {
            result.error("INVALID_ARGUMENT", "treeUri is required", null)
            return
        }

        try {
            val treeUri = Uri.parse(treeUriStr)
            val documentFile = DocumentFile.fromTreeUri(activity, treeUri)
            if (documentFile == null || !documentFile.exists()) {
                result.success(emptyList<Map<String, Any>>())
                return
            }

            val pdfFiles = mutableListOf<Map<String, Any>>()
            collectDocumentFiles(documentFile, pdfFiles)

            result.success(pdfFiles)
        } catch (e: Exception) {
            result.error("LIST_ERROR", e.message, null)
        }
    }

    private fun collectDocumentFiles(directory: DocumentFile, result: MutableList<Map<String, Any>>) {
        for (file in directory.listFiles()) {
            if (file.isDirectory) {
                collectDocumentFiles(file, result)
            } else if (file.isFile && file.name?.lowercase()?.endsWith(".pdf") == true) {
                result.add(
                    mapOf(
                        "uri" to file.uri.toString(),
                        "name" to (file.name ?: ""),
                        "size" to file.length(),
                        "lastModified" to file.lastModified()
                    )
                )
            }
        }
    }

    private fun readFileBytes(call: MethodCall, result: MethodChannel.Result) {
        val documentUriStr = call.argument<String>("documentUri")
        if (documentUriStr == null) {
            result.error("INVALID_ARGUMENT", "documentUri is required", null)
            return
        }

        try {
            val documentUri = Uri.parse(documentUriStr)
            val bytes = activity.contentResolver.openInputStream(documentUri)?.use {
                it.readBytes()
            }

            if (bytes == null) {
                result.error("READ_ERROR", "Could not open input stream", null)
                return
            }

            result.success(bytes)
        } catch (e: Exception) {
            result.error("READ_ERROR", e.message, null)
        }
    }

    private fun copyToLocal(call: MethodCall, result: MethodChannel.Result) {
        val documentUriStr = call.argument<String>("documentUri")
        val destPath = call.argument<String>("destPath")
        if (documentUriStr == null || destPath == null) {
            result.error("INVALID_ARGUMENT", "documentUri and destPath are required", null)
            return
        }

        try {
            val documentUri = Uri.parse(documentUriStr)
            val destFile = java.io.File(destPath)
            destFile.parentFile?.mkdirs()

            activity.contentResolver.openInputStream(documentUri)?.use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: run {
                result.error("COPY_ERROR", "Could not open input stream", null)
                return
            }

            result.success(destPath)
        } catch (e: Exception) {
            result.error("COPY_ERROR", e.message, null)
        }
    }

    private fun writeFile(call: MethodCall, result: MethodChannel.Result) {
        val treeUriStr = call.argument<String>("treeUri")
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")

        if (treeUriStr == null || fileName == null || bytes == null) {
            result.error("INVALID_ARGUMENT", "treeUri, fileName, and bytes are required", null)
            return
        }

        try {
            val treeUri = Uri.parse(treeUriStr)
            val parentDoc = DocumentFile.fromTreeUri(activity, treeUri)
            if (parentDoc == null) {
                result.error("WRITE_ERROR", "Could not access directory", null)
                return
            }

            val newFile = parentDoc.createFile("application/pdf", fileName)
            if (newFile == null) {
                result.error("WRITE_ERROR", "Could not create file", null)
                return
            }

            activity.contentResolver.openOutputStream(newFile.uri)?.use {
                it.write(bytes)
            }

            result.success(newFile.uri.toString())
        } catch (e: Exception) {
            result.error("WRITE_ERROR", e.message, null)
        }
    }

    private fun getFileMetadata(call: MethodCall, result: MethodChannel.Result) {
        val documentUriStr = call.argument<String>("documentUri")
        if (documentUriStr == null) {
            result.error("INVALID_ARGUMENT", "documentUri is required", null)
            return
        }

        try {
            val documentUri = Uri.parse(documentUriStr)
            val cursor = activity.contentResolver.query(
                documentUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED
                ),
                null, null, null
            )

            if (cursor == null) {
                result.error("METADATA_ERROR", "Could not query metadata", null)
                return
            }

            cursor.use {
                if (!it.moveToFirst()) {
                    result.error("METADATA_ERROR", "Could not query metadata", null)
                    return
                }
                val size = it.getLong(0)
                val lastModified = it.getLong(1)
                result.success(mapOf("size" to size, "lastModified" to lastModified))
            }
        } catch (e: Exception) {
            result.error("METADATA_ERROR", e.message, null)
        }
    }

    private fun deleteFile(call: MethodCall, result: MethodChannel.Result) {
        val documentUriStr = call.argument<String>("documentUri")
        if (documentUriStr == null) {
            result.error("INVALID_ARGUMENT", "documentUri is required", null)
            return
        }

        try {
            val documentUri = Uri.parse(documentUriStr)
            val documentFile = DocumentFile.fromSingleUri(activity, documentUri)
            val deleted = documentFile?.delete() ?: false
            result.success(deleted)
        } catch (e: Exception) {
            result.error("DELETE_ERROR", e.message, null)
        }
    }

    private fun fileExists(call: MethodCall, result: MethodChannel.Result) {
        val documentUriStr = call.argument<String>("documentUri")
        if (documentUriStr == null) {
            result.error("INVALID_ARGUMENT", "documentUri is required", null)
            return
        }

        try {
            val documentUri = Uri.parse(documentUriStr)
            val documentFile = DocumentFile.fromSingleUri(activity, documentUri)
            result.success(documentFile?.exists() ?: false)
        } catch (e: Exception) {
            result.success(false)
        }
    }
}
