component {
	property name="obj_b" relationship="many-to-one" relatedto="object_b" required=true;
	property name="a_count" formula="Count( ${prefix}obj_b$lots_of_a.id )";
}