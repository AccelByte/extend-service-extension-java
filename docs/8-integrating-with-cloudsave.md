# Chapter 8: Integrating with AccelByte's CloudSave

In this chapter, we'll learn how to integrate the AccelByte's CloudSave feature into our GuildService.

## 8.1. Understanding CloudSave

AccelByte's CloudSave is a cloud-based service that enables you to save and retrieve game data in 
a structured manner. It allows for easy and quick synchronization of player data across different 
devices. This can be especially useful in multiplayer games where players' data needs to be synced 
in real-time. Please refer to our docs portal for more details

## 8.2. Setting up CloudSave

The first step to using CloudSave is setting it up. 
In the context of our GuildService, this involves adding Java AccelByteSdk to our service and bootstrap it.
We will use dependency injection to supply the AccelByteSDK object to our service implementation class.

1. Java Accelbyte SDK instance, we're using spring dependency injection, please refer to `src/main/java/net/accelbyte/extend/serviceextension/config/AppConfig.java` for method `provideAccelbyteSdk()` 

2. Create `AdminGameRecord` which that wraps all Cloudsave operation for us, refer to `src/main/java/net/accelbyte/extend/serviceextension/storage/CloudsaveStorage.java`


## 8.3. Using CloudSave in GuildService

Let's go over an example of how we use CloudSave within our GuildService.

When updating the guild progress, after performing any necessary validations and computations, 
you would save the updated progress to CloudSave like so:

```java
    public GuildProgress getGuildProgress(String namespace, String key) throws Exception {
        AdminGetGameRecordHandlerV1 input = AdminGetGameRecordHandlerV1.builder()
                .namespace(namespace)
                .key(key)
                .build();
        ModelsGameRecordResponse response = csStorage.adminGetGameRecordHandlerV1(input);
        CloudSaveModel model = mapper.convertValue(response.getValue(), CloudSaveModel.class);
        return model.toGuildProgress();
    }

    public GuildProgress saveGuildProgress(String namespace, String key, GuildProgress value) throws Exception {
        CloudSaveModel cloudModel = new CloudSaveModel(value);
        AdminPostGameRecordHandlerV1 input = AdminPostGameRecordHandlerV1.builder()
                .namespace(namespace)
                .key(key)
                .body(cloudModel)
                .build();
        ModelsGameRecordResponse response = csStorage.adminPostGameRecordHandlerV1(input);
        CloudSaveModel model = mapper.convertValue(response.getValue(), CloudSaveModel.class);
        return model.toGuildProgress();
    }
```

For more accurate details how it was implemented please refer to [src/main/java/net/accelbyte/extend/serviceextension/storage/CloudsaveStorage.java](src/main/java/net/accelbyte/extend/serviceextension/storage/CloudsaveStorage.java)

That's it! You've now integrated AccelByte's CloudSave into your GuildService. 
You can now use CloudSave to save and retrieve guild progress, along with any other 
data you might need to store.