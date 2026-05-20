import { v2 as cloudinary, UploadApiResponse, UploadApiErrorResponse } from "cloudinary";
import fs from "fs";

// Configure Cloudinary
cloudinary.config({ 
  cloud_name: 'ddjphksjr',
  api_key: '184719526989741', 
  api_secret: 'OU2Hh3gCrAStgsxHb-MdmkBVNec',
})


// Upload from file path
export const uploadOnCloudinary = async (
  localFilePath: string
): Promise<UploadApiResponse | null> => {
  try {
    if (!localFilePath) return null;

    const response: UploadApiResponse = await cloudinary.uploader.upload(localFilePath, {
      resource_type: "auto",
      timeout: 60000
    });

    // Remove local file after successful upload
    fs.unlinkSync(localFilePath);
    return response;
  } catch (error) {
    console.error("Upload failed:", error);
    if (fs.existsSync(localFilePath)) {
      fs.unlinkSync(localFilePath);
    }
    return null;
  }
};

// Upload from buffer (for form data)
export const uploadBufferToCloudinary = async (
  buffer: Buffer,
  options?: any
): Promise<UploadApiResponse | null> => {
  try {
    return await new Promise((resolve, reject) => {
      cloudinary.uploader.upload_stream(
        { resource_type: "auto", ...options },
        (error, result) => {
          if (error) {
            reject(error);
            return;
          }
          resolve(result as UploadApiResponse);
        }
      ).end(buffer);
    });
  } catch (error) {
    console.error("Buffer upload failed:", error);
    return null;
  }
};