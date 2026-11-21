
import 'package:ride_sharing_user_app/features/message/domain/models/channel_model.dart';

class MessageModel {
    String? responseCode;
    String? message;
    int? totalSize;
    String? limit;
    String? offset;
    List<Message>? data;

   MessageModel({
     this.responseCode,
     this.message,
     this.totalSize,
     this.limit,
     this.offset,
     this.data,
   });

  MessageModel.fromJson(Map<String, dynamic> json){
    responseCode = json['response_code'];
    message = json['message'];
    totalSize = int.tryParse(json['total_size'].toString());
    limit = json['limit'];
    offset = json['offset'];
    data = List.from(json['data']).map((e)=>Message.fromJson(e)).toList();

  }

}

class Message {
   int? id;
   String? userId;
   String? message;
   String? tripId;
   String? updatedAt;
   String? createdAt;
   List<ConversationFiles>? conversationFiles;
   User? user;
   /// The other party has read it (read receipt).
   bool isRead = false;
   /// Shown before the server confirmed it (optimistic send).
   bool isPending = false;
   bool isFailed = false;
   Message({
     this.id,
     this.userId,
     this.message,
     this.updatedAt,
     this.conversationFiles,
     this.user,
     this.tripId,
     this.isRead = false,
     this.isPending = false,
   });

  Message.fromJson(Map<String, dynamic> json){
    id = int.tryParse(json['id'].toString());
    userId = json['user_id'];
    message = json['message'];
    tripId = json['trip_id'];
    updatedAt = json['updated_at'];
    createdAt = json['created_at'];
    if (json['conversation_files'] != null) {
      conversationFiles = <ConversationFiles>[];
      json['conversation_files'].forEach((v) {
        conversationFiles!.add(ConversationFiles.fromJson(v));
      });
    }
    user = json['user'] != null ? User.fromJson(json['user']) : null;
    isRead = json['is_read'] == true || json['is_read'] == 1 || json['is_read'] == '1';
  }
}
class ConversationFiles {
  int? id;
  String? fileName;
  String? fileType;

  ConversationFiles({this.id, this.fileName, this.fileType});

  ConversationFiles.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'].toString());
    fileName = json['file_name'];
    fileType = json['file_type'];
  }

}