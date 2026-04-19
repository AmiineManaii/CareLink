const cloudinary = require('../config/cloudinary');
const streamifier = require('streamifier');

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