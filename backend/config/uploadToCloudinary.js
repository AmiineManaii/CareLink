const { v2: cloudinary } = require('cloudinary');
const streamifier = require('streamifier');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

/**
 * @param {Buffer} fileBuffer
 * @param {string} folder
 * @param {'image'|'video'|'raw'|'auto'} resourceType - default: 'image'
 */
const uploadToCloudinary = (fileBuffer, folder, resourceType = 'image') => {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: resourceType },
      (error, result) => {
        if (result) resolve(result.secure_url);
        else reject(error);
      }
    );

    streamifier.createReadStream(fileBuffer).pipe(stream);
  });
};

module.exports = uploadToCloudinary;