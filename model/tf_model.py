import tempfile
import os

# Set the environment variable TF_USE_LEGACY_KERAS to '0'
import tensorflow as tf

from tensorflow_model_optimization.python.core.keras.compat import keras

# Load MNIST dataset
mnist = tf.keras.datasets.mnist
(train_images, train_labels), (test_images, test_labels) = mnist.load_data()

# Normalize the input image so that each pixel value is between 0 to 1.
train_images = train_images / 255.0
test_images = test_images / 255.0

q_aware_model = None
try:
    q_aware_model = tf.keras.models.load_model('q_aware_model')
except:
    # Define the model architecture.
    model = keras.Sequential([
    keras.layers.InputLayer(input_shape=(28, 28)),
    keras.layers.Reshape(target_shape=(28, 28, 1)),
    keras.layers.Conv2D(filters=2, kernel_size=(5, 5), activation='relu'),
    keras.layers.MaxPooling2D(pool_size=(2, 2)),
    keras.layers.Conv2D(filters=4, kernel_size=(3, 3), activation='relu'),
    keras.layers.MaxPooling2D(pool_size=(2, 2)),
    keras.layers.Flatten(),
    keras.layers.Dense(10)
    ])

    # Train the digit classification model
    model.compile(optimizer='adam',
                loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
                metrics=['accuracy'])

    model.fit(
    train_images,
    train_labels,
    epochs=5,
    validation_split=0.1,
    )

    import tensorflow_model_optimization as tfmot

    quantize_model = tfmot.quantization.keras.quantize_model

    # q_aware stands for for quantization aware.
    q_aware_model = quantize_model(model)

    # `quantize_model` requires a recompile.
    q_aware_model.compile(optimizer='adam',
                loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
                metrics=['accuracy'])

    q_aware_model.summary()

    train_images_subset = train_images[0:1000] # out of 60000
    train_labels_subset = train_labels[0:1000]

    q_aware_model.fit(train_images_subset, train_labels_subset,
                    batch_size=500, epochs=1, validation_split=0.1)
    
    q_aware_model.save('q_aware_model')

    _, baseline_model_accuracy = model.evaluate(
        test_images, test_labels, verbose=0)
    
    print('Baseline test accuracy:', baseline_model_accuracy)

_, q_aware_model_accuracy = q_aware_model.evaluate(
   test_images, test_labels, verbose=0)

print('Quant test accuracy:', q_aware_model_accuracy)


# **Export weights and biases for FPGA implementation**

# Convert the quantized model to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(q_aware_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]

tflite_model = converter.convert()

# Save the TFLite model to a file
tflite_model_file = 'quantized_model.tflite'
with open(tflite_model_file, 'wb') as f:
    f.write(tflite_model)

# Load the TFLite model
interpreter = tf.lite.Interpreter(model_path=tflite_model_file, experimental_preserve_all_tensors=True)
interpreter.allocate_tensors()

# Get details of tensors
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("== Input details ==")
print("name:", input_details[0]['name'])
print("shape:", input_details[0]['shape'])
print("type:", input_details[0]['dtype'])
print("\n== Output details ==")
print("name:", output_details[0]['name'])
print("shape:", output_details[0]['shape'])
print("type:", output_details[0]['dtype'])

'''
Run prediction (optional), input_array has input's shape and dtype
interpreter.set_tensor(input_details[0]['index'], input_array)
interpreter.invoke()
output_array = interpreter.get_tensor(output_details[0]['index'])
'''

'''
This gives a list of dictionaries. 
'''
tensor_details = interpreter.get_tensor_details()

for dict in tensor_details:
    i = dict['index']
    tensor_name = dict['name']
    scales = dict['quantization_parameters']['scales']
    zero_points = dict['quantization_parameters']['zero_points']
    tensor = interpreter.tensor(i)()

    print(i, tensor_name, scales.shape, zero_points.shape, tensor.shape)