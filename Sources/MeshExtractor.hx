package;
import OgexData.Node;
import kha.graphics4.Usage;
import kha.graphics4.IndexBuffer;
import kha.graphics4.VertexBuffer;
import kha.graphics4.VertexData;
import kha.graphics4.VertexStructure;
import kha.math.FastMatrix4;
import OgexData.GeometryNode;
import kha.Image;
import kha.Assets;

/**
 * ...
 * @author Joaquin
 */
class MeshExtractor
{

	public static function extract(aData:OgexData,aSkeletons:Array<SkeletonD>):Array<Object3d> 
	{
		
		var structure = new VertexStructure();
		structure.add('pos', VertexData.Float3);
		structure.add('normal', VertexData.Float3);
		structure.add('uv',VertexData.Float2);
		if(aSkeletons!=null&&aSkeletons.length!=0){
		structure.add('weights',VertexData.Float4);
		structure.add('boneIndex',VertexData.Float4);
		}
		var result = new Array<Object3d>();
		var geometries = aData.geometryObjects;
		for (geomtry in geometries) 
		{
			var vertices = geomtry.mesh.vertexArrays[0].values;
			var normals = geomtry.mesh.vertexArrays[1].values;
			var uv = geomtry.mesh.vertexArrays[2].values;
			var indices = geomtry.mesh.indexArray.values;
			var skin = geomtry.mesh.skin;
			var textureName=null;
			for(child in aData.children)
			{
				 textureName=getTextureName(child,aData,geomtry.ref);
				 if(textureName!=null) break;
			}
			if(textureName==null||textureName==""){
				continue;
			}
			var texture:Image =cast Reflect.field(Assets.images,textureName);
			if(texture!=null)texture.generateMipmaps(3);
			

			var boneIndexs=new Array<Int>();
			var boneWeight=new Array<Float>();
			if(aSkeletons!=null&&aSkeletons.length!=0){
				

				var counter:Int=0;
				for(numAffectingBones in skin.boneCountArray.values){
					for(i in 0...numAffectingBones)
					{
						boneIndexs.push(skin.boneIndexArray.values[counter+i]);
						boneWeight.push(skin.boneWeightArray.values[counter+i]);
					}
					counter+=numAffectingBones;
					if(numAffectingBones>4) throw "implementation limited to 4 bones per vertex";
					for(i in numAffectingBones...4) //fill up to 4 bones per vertex
					{
						boneIndexs.push(0);
						boneWeight.push(0);
					}
				}
			}
			
			var vertexBuffer = new VertexBuffer(vertices.length, structure, Usage.StaticUsage);
			var buffer = vertexBuffer.lock();
			if(aSkeletons!=null&&aSkeletons.length!=0){
			for (i in 0...Std.int(vertices.length / 3)) {
				buffer.set(i * 16 + 0, vertices[i * 3 + 0]);
				buffer.set(i * 16 + 1, vertices[i * 3 + 1]);
				buffer.set(i * 16 + 2, vertices[i * 3 + 2]);
				buffer.set(i * 16 + 3, normals[i * 3 + 0]);
				buffer.set(i * 16 + 4, normals[i * 3 + 1]);
				buffer.set(i * 16 + 5, normals[i * 3 + 2]);
				buffer.set(i * 16 + 6, uv[i*2+0]);
				buffer.set(i * 16 + 7, 1-uv[i*2+1]);
				buffer.set(i * 16 + 8, boneWeight[i * 4 + 0]);
				buffer.set(i * 16 + 9, boneWeight[i * 4 + 1]);
				buffer.set(i * 16 + 10, boneWeight[i * 4 + 2]);
				buffer.set(i * 16 + 11, boneWeight[i * 4 + 3]);
				buffer.set(i * 16 + 12, boneIndexs[i * 4 + 0]);
				buffer.set(i * 16 + 13, boneIndexs[i * 4 + 1]);
				buffer.set(i * 16 + 14, boneIndexs[i * 4 + 2]);
				buffer.set(i * 16 + 15, boneIndexs[i * 4 + 3]);
			}
			}else{
				for (i in 0...Std.int(vertices.length / 3)) {
				buffer.set(i * 8 + 0, vertices[i * 3 + 0]);
				buffer.set(i * 8 + 1, vertices[i * 3 + 1]);
				buffer.set(i * 8 + 2, vertices[i * 3 + 2]);
				buffer.set(i * 8 + 3, normals[i * 3 + 0]);
				buffer.set(i * 8 + 4, normals[i * 3 + 1]);
				buffer.set(i * 8 + 5, normals[i * 3 + 2]);
				buffer.set(i * 8 + 6, uv[i*2+0]);
				buffer.set(i * 8 + 7, 1-uv[i*2+1]);
				}
			}
			vertexBuffer.unlock();
			
			var indexBuffer = new IndexBuffer(indices.length, Usage.StaticUsage);
			var ibuffer = indexBuffer.lock();
			for (i in 0...indices.length) {
				ibuffer[i] = indices[i];
			}
			indexBuffer.unlock();
			var object3d = new Object3d();
			
			if(aSkeletons!=null&&aSkeletons.length!=0){
				var bones:Array<Bone> = new Array();
				var skeleton = skin.skeleton;
				var bonesNames = skeleton.boneRefArray.refs;
				for (name in bonesNames) 
				{
					for (sk in aSkeletons) 
					{
						var bone = sk.getBone(name);
						if (bone != null) {
							bones.push(bone);
							break;
						}
					}
				}
			
				if (bones.length != bonesNames.length) throw "some skined bones not found `v('~')v´";
				for (i in 0...skeleton.transforms.length) 
				{
					bones[i].bindTransform = FastMatrix4.empty();
					Bone.matrixFromArray(skeleton.transforms[i].values, 0, bones[i].bindTransform);
				}
				var skining:Skinning = new Skinning(bones);
				object3d.skin = skining;
			}
			
			
			object3d.vertexBuffer = vertexBuffer;
			object3d.indexBuffer = indexBuffer;
				
			object3d.animated=(aSkeletons!=null&&aSkeletons.length!=0);
			object3d.texture=texture;
			result.push(object3d);
		}
		return result;
	}
	static function getTextureName(aNode:Node,aData:OgexData,aRef:String):String
	{
		if(Std.is(aNode,GeometryNode))
		{
			var gNode:GeometryNode=cast aNode;
			if(aRef==gNode.objectRefs[0])
			{
				var material=aData.getMaterial(gNode.materialRefs[0]);
				if(material.texture.length==0)return "";
				var path=material.texture[0].path;
				var parts=path.split("/");
				return parts[parts.length-1].split(".")[0];
			}
		}
		for(node in aNode.children)
		{
			var name = getTextureName(node,aData,aRef);
			if( name != null ) return name;	
		}
		return null;
	}
	
}